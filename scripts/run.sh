#!/bin/bash

if [[ $# -ne 2 ]]; then
	echo "Wrong number of arguments"
fi

hosts=$(sed '1!d' /media/share/all_ips | cut -d':' -f2):1

if [[ $2 -gt 1 ]]; then
	for ((i = 2; i <= $2 ; i++)); do
		current_ip=$(sed "$i"'!d' /media/share/all_ips | cut -d':' -f2)
		hosts="$hosts,$current_ip:1"
	done
else
	hosts="$(hostname):1"
fi

horovodrun -np $2 -H $hosts python3 $1 --epochs 3