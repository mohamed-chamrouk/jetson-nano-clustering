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
    #print(f"cpu_temp:{cpu_temp}, gpu_temp:{gpu_temp}, cpu_freq:{cpu_freq}, gpu_freq:{gpu_freq}, cpu_power:{cpu_power}, gpu_power:{gpu_power}, total_power:{total_power}, ram:{ram}, swap:{swap}")    
    cur.execute(sql, (AsIs(HOSTNAME), cpu_temp, gpu_temp, cpu_freq, gpu_freq, cpu_power, gpu_power, total_power, ram, swap))

    conn.commit()