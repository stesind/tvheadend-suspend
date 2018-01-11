#!/bin/bash
if [ -z "$1" ] 
then 
	echo "Parameter empty!"
	read -p "Add the signal -15 (sigterm) or -9 (sigkill) default -15 " param
	if [ -z "$param" ]
	then
		param="-15"
	fi
else
	param=$1
fi

for (( x = 1 ; x <= 5 ; x++ ))
do
	if [ $x -ge 4 ]
	then 
		param="-9"
	fi
	for i in `ps ax | grep kodi.bin | grep -v grep | sed 's/ *//' | sed 's/[^0-9].*//'`
	do     		
		echo "executing kill $param"
  		kill $param $i
	done
	sleep 1
done
