#!/bin/bash
date=`date +"%s"`
logdir="/root/gorgon-logs"
failedlog="$logdir/failed.$date.log"
mkdir -p $logdir

if [ $# -lt 3 ] ; then
	echo "Usage: $0 user host-file script [params ...]"
	exit 0
fi

user=$1
host_file=$2
script=$3
params="${@:4}"
failed=0
response=n

echo "Configuration:"
echo "User = \"$user\""
echo "Script = \"$script\""
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
	echo "Copying $script to $user@$host..." | tee -a $log
	scp $script $user@$host:~ 2>&1 | tee -a $log
	have_i_failed $user $host
	if [ $? -ne 0 ] ; then
		continue
	fi

	echo "Executing command on $user@$host..." | tee -a $log
	0</dev/null ssh $user@$host ./$script $params 2>&1 | tee -a $log
	have_i_failed $user $host
	if [ $? -ne 0 ] ; then
		continue
	else
		echo -e "\e[0;32mSuccess!\e[0m" | tee -a $log
	fi

	echo "Removing $script from $user@$host..." | tee -a $log
	0</dev/null ssh $user@$host rm $script 2>&1 | tee -a $log
	have_i_failed $user $host
	if [ $? -ne 0 ] ; then
		continue
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


