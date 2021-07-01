#!/bin/bash

ip=$(/sbin/ifconfig eth0 | grep 'inet ' | cut -d' ' -f10)
hostname=$(hostname)

echo $hostname:$ip > /media/share/$hostname