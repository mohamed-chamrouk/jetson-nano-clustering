#!/bin/bash

trap "tegrastats --stop; kill_tegra" EXIT
logfile=$(hostname | cut -d'-' -f1).log

kill_tegra() {
	pid=$(pidof tegrastats)
	if [[ -n $pid ]]; then
		if [[ $pid -gt 0 ]]; then
			echo "$(date) : [KILL] Killing process $pid" >> ../jetson-logs/$logfile
			sudo kill -9 $pid
		fi
	fi
}

statfile=$(hostname | cut -d'-' -f1).stat

kill_tegra
sleep 1
sudo tegrastats --start --logfile /media/share/jetson-stats/$statfile

/usr/bin/python3 stats_to_database.py

while true; do
	sleep 600
	echo "$(date) : [EMPTY] Emptying stat file" >> ../jetson-logs/$logfile
	sed -i -e '1,500d' ../jetson-stats/$statfile
done
