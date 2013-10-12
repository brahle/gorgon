#!/bin/bash
date=`date +"%s"`
logdir="$HOME/.gorgon/logs"
failedlog="$logdir/failed.$date.log"
mkdir -p $logdir

if [ $? -ne 0 ] ; then
	echo "Unable to create logdir $logdir."
	echo "Please check if you have write permissions there!"
	exit 1
fi

if [ $# -lt 3 ] ; then
	echo "Usage: $0 user host-file command [params ...]"
	exit 0
fi

user=$1
host_file=$2
command=$3
#TODO: params aren't working correctly when there are spaces
params="${@:4}"
failed=0
response=n
need_to_copy=0

if [ -f $command ] ; then
	full_path=$command
	script=`basename $command`
	command="./$script"
	need_to_copy=1
fi

echo "Configuration:"
echo "User = \"$user\""
echo "Logdir = \"$logdir\""
echo "Command = \"$command\""
echo "File with hosts = \"$host_file\""
echo "First few lines of the $host_file:"
head $host_file 
echo "Script params: $params"

until [ $response == "y" ]; do
	echo "Is config OK (y/n)?"
	read response
	if [ $response == "n" ]; then
		echo "Exiting!"
		exit
	fi
done

function have_i_failed {
	exit_code=${PIPESTATUS[0]}
	if [ $exit_code -ne 0 ] ; then
		echo -e "****** \e[1;31mFAIL for $1@$2\e[0m ******" | tee -a $log
		echo $2 >> $failedlog
		failed=1
		return 1
	fi
	return 0
}

total=0
ok=0
while read host ; do
	name="$user.at.$host"
	log="$logdir/$name.log"
	total=$(($total+1))
	touch $log
	echo "***********************************************" | tee -a $log

	if [ $need_to_copy -eq 1 ] ; then
		echo "Copying $command to $user@$host..." | tee -a $log
		scp $full_path $user@$host:~ 2>&1 | tee -a $log
		have_i_failed $user $host
		if [ $? -ne 0 ] ; then
			continue
		fi
	fi

	echo "Executing command '$command $params' on $user@$host..." | tee -a $log
	0</dev/null ssh $user@$host $command $params 2>&1 | tee -a $log
	have_i_failed $user $host
	if [ $? -ne 0 ] ; then
		continue
	else
		echo -e "\e[0;32mSuccess!\e[0m" | tee -a $log
	fi

	if [ $need_to_copy -eq 1 ] ; then
		echo "Removing $script from $user@$host..." | tee -a $log
		0</dev/null ssh $user@$host rm $script 2>&1 | tee -a $log
		have_i_failed $user $host
		if [ $? -ne 0 ] ; then
			continue
		fi
	fi
	
	ok=$(($ok+1))
	echo "Done!" | tee -a log
done <$host_file

echo "***********************************************"
echo -e "OK on \e[1m$ok/$total\e[0m hosts."
if [ $failed -ne 0 ] ; then
	echo -e "\e[1;31mThere were failures\e[0m"
	echo -e "See logfile $failedlog to see which hosts have failed"
else
	echo -e "\e[1;32mGreat success! (All OK)\e[0m"
fi


