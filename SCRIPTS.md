# Scripts explanation

## Adding users

In order to make it easier to add a new user to the cluster I've wrote a small script that takes care of everything :

```bash
#!/bin/bash

if [[ $# -ne 1 ]]; then
    echo "Error : Wrong number of arguments"
    exit
fi

adduser $1
echo "/home/$1 192.168.0.0/24(rw,sync,no_subtree_check)" >> /etc/exports
systemctl restart nfs-kernel-server

while IFS= read -r line; do
    host=$(echo $line | cut -d':' -f2)
    echo "192.168.0.1:/home/$1 /home/$1 nfs defaults,user,exec 0 0" > fstab.txt
    echo "$1:$1:::,,,:/home/$1:/bin/bash" > /media/nfs/new_user.txt
    ssh -tt root@$host newusers /media/share/new_user.txt < /dev/null
    ssh -tt root@host 'cat /media/Share/fstab.txt >> /etx/fstab' < /dev/null
    ssh -tt root@$host 'mount -a' < /dev/null
done < all_ips
```

This script adds a user that's been given as the first argument through the command : `./add_user.sh user`. User interaction is needed to add the user to the master machine (our nfs server) but the spreading of the user through the other machines is done without any user interaction (the password used is the same as the username which obviously needs to be changed).

## Grafana Server

First install a postgresql server on your machine with [this guide](https://www.microfocus.com/documentation/idol/IDOL_12_0/MediaServer/Guides/html/English/Content/Getting_Started/Configure/_TRN_Set_up_PostgreSQL_Linux.htm) (any other database framework should work, make sure it's supported by Grafana first).

Then we create tables for each board :
```sql
CREATE
TABLE public.jetsonX_stats(
    id serial PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cpu_temp FLOAT,
    gpu_temp FLOAT,
    cpu_freq FLOAT,
    gpu_freq FLOAT,
    cpu_power FLOAT,
    gpu_power FLOAT,
    total_power FLOAT,
    ram FLOAT,
    swap FLOAT
);
```
(where X is the number of your board, ours start from 0 up to 7).

Once this is done we can create the service that'll manage the data. The file is available in /scripts/granafa/stat-launcher.service

This service launcher the following script (stat_launcher.sh) :
```bash
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
```

Which launches the utility tegrastats that allows us to get all the statistics from the board. The `--logfile` option saves the output to a file located on an nfs storage.

This script then launches the following python script :
```python
#!/usr/bin/python3

import psycopg2 as pg
from psycopg2.extensions import AsIs
import subprocess as sp
import sys
import re
import numpy as np
import time
from subprocess import PIPE


conn = pg.connect(
        host="192.168.0.1",
        port="3003",
        database="grafanadb",
        user="snow",
        password="J3t50Npsql")

cur = conn.cursor()
sql = "INSERT INTO public.%s_stats (cpu_temp, gpu_temp, cpu_freq, gpu_freq, cpu_power, gpu_power, total_power, ram, swap) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s);"


HOSTNAME = sp.run(["hostname"], stdout=PIPE).stdout.decode("utf-8").partition('-')[0]

def find_stat(string_stat, string1, string2):
    index = string_stat.find(string1)
    return string_stat[index+len(string1):string_stat[index:].find(string2)+index]

while True:
    time.sleep(5)
    with open(f"/media/share/jetson-stats/{HOSTNAME}.stat") as f:
        for line in f:
            pass
        last_stat = line
    
    cpu_temp = find_stat(last_stat, "CPU@", "C ")
    gpu_temp = find_stat(last_stat, "GPU@", "C ")
    cpu_freq = np.mean([int(i) for i in re.findall(r'(\d+)+%', last_stat[last_stat.find("["):last_stat.find("]")+1])])
    gpu_freq = find_stat(last_stat,"GR3D_FREQ ", "%")
    cpu_power = find_stat(last_stat,"POM_5V_CPU ","/")
    gpu_power = find_stat(last_stat,"POM_5V_GPU ","/")
    total_power = find_stat(last_stat,"POM_5V_IN ","/")
    ram = find_stat(last_stat,"RAM ","/")
    swap = find_stat(last_stat,"SWAP ","/")
    cur.execute(sql, (AsIs(HOSTNAME), cpu_temp, gpu_temp, cpu_freq, gpu_freq, cpu_power, gpu_power, total_power, ram, swap))

    conn.commit()
```
This script uses regex rules to get the detailed statistics and commits them to the database every 5 seconds.

Once everything is in place you can head to your grafana dashboard and create panes for each metric.

## Launching the cluster terminal

tmux is a tool that allows us to launch a terminal session detached from the ssh session it's been launched in.
It also allows for multiple panes to be launched at the same time.

If a commandline needs to be executed for each board in the cluster, the following command can be used to launch synchronized terminals :
```bash
tmux  new-session -s cluster "ssh jetson@192.168.0.100" \;  split-window "ssh jetson@192.168.0.104" \; split-window -h "ssh jetson@192.168.0.106" \; select-pane -t 0 \; split-window -h "ssh jetson@192.168.0.102" \; select-pane -t 0 \; split-window -h "ssh jetson@192.168.0.101" \; select-pane -t 2 \; split-window -h "ssh jetson@192.168.0.103" \; select-pane -t 4 \; split-window -h "ssh jetson@192.168.0.105" \; select-pane -t 6 \; split-window -h "ssh jetson@192.168.0.107" \; setw synchronize-panes on
```