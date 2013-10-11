gorgon
======

A shell script that executes another script on a list of remote servers


Prereqs
=======

1. You have root access to machine you are running gorgon from. TODO: This is not actually needed. Fix it.
2. You have SSH keys set up and you don't need to type in a password on any of the hosts listed


Example
=======

Host file should have a list of IPs (or hostnames) that you want to execute a
script on. 

For example, let's say file `host_example.txt` has the following IPs:

```
192.168.1.1
192.168.1.2
```

You could try and run `./gorgon.sh root host_example.txt test.sh Every server should output this`. The result should be that all hosts successfully output "Every server should output this".
