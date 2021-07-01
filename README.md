# Jetson Nano Clustering

## Quick Introduction

This project was made in collaboration with [Télécom SudParis](https://www.telecom-sudparis.eu/) for a cost-efficient solution for machine learning model training.

Although meant to be used with the python library [Pytorch](https://pytorch.org/) and [Horovod](https://horovod.ai/) the cluster can, of course, be adapted for the use of other librairies (although this means that you will have to debug any issue yourself).

Now for the cluster, there are two ways though which we explored it :
- Clustering through MPI : MPI or Message Passing Interface is a standard meant for distributed applications. This standard is here used through Horovod.
    - Benefits : Easy to understand and implement.
    - Drawbacks : Long configuration time, limitations for ressources.
- Clustering through kubernetes : Pretty self-explanatory, kubernetes allows us to create a cluster with a simple architecture of master-workers.
    - Benefits : Easy to configure, easily scalable, good use of ressources.
    - Drawbacks : One node is "lost" as a master, configuration can be hard when needing specific libraries.
    > :warning: Kubernetes isn't meant for this type of usecase. Kubeflow through the MPI Training operator or more simply horovod can be used for that task. We'll see later on how this affects performance compared to the bare-bone solution.
<div></div>
These two ways of clustering will be explored further down with everything needed to make it work under jetson nanos.

A separate guide is available on the repo to use the cluster in both of its forms.
<br>
<br>

##  Nota Bene

Some things to note before getting going full force into installation, configuration and all that stuff :
- Jetson Nano cards need to have a "clean" sd card (with a fresh installation of the image provided by Nvidia) upon first boot. I'm thinking this comes down to OEM configuration with the GPU in the image that Nvidia provides. So booting with a sd card with a clone image of another jetson nano **won't work**. 
- Keep in mind that the architecture of the CPUs used inside the jetson nanos are ARM64, so solutions to wider issues met with the jetson nanos won't always work.
- You can clone an SD Card from balena etcher software. It prevents the use of unnecessary space on your computer (with the dd method).
- I've messed up sometimes with hostnames and found out that if your hostname doesn't match the content of the `/etc/hosts` file your `sudo` commands will take a lot longer to launch.

## Setup

Here is our setup for our cluster :
- 8 jetson nano developer kits
- 8 high speed sd card (we used 100Mbit/s 128Gb SD Card, but it's a bit overkill. Favor speed/endurance inspite of storage space)
- 1 gigabit network switch
- A server for storage (NFS in our case)
<div></div>

First and foremost, and this is true in general for jetson nano developer kits :
### First boot
This is fairly straight forward, there is a [complete guide](https://developer.nvidia.com/embedded/learn/get-started-jetson-nano-devkit#next) on Nvidia's website for how to setup a jetson nano.
> :warning: For the MPI/horovod 'cluster' you need to have a swap partition, so right before the end of the configuration, when you get asked how much you want to leave for disk space, remove 4gb to 8gb from it.

> :information_source: Small optional tip : It's best to configure well your hostnames and password during this step. It's a real hassle figuring things out later on so the sooner the better.

As mentionned in the *Nota Bene* section, you have to do this with every single one of your jetson nanos regardless of the way you choose to setup your cluster.

Although simple this part is the one that probably will take you the most amount of time. SD Cards are flash storage, so not terribly fast.

### Networking
In our case, every jetson nano had a public IP address making the configuration easier. However it's best practice to have static local adresses for each jetson nano. One way to do that is through routing on (for instance) the nfs server. By setting up a NAT on this server and connecting the switch to it, it will allow each jetson nano to have a local adress while still being able to access internet.
> Note that this means you need to have two network interfaces on your server (which we didn't have hence the public adresses).

### NFS Server [¹]

**Server side** : <div></div>
Installing the nfs server is done through:
```bash
sudo apt install nfs-kernel-server
```
We then configure which folder we want to share:
```bash
/media/nfs		x.x.x.x/yy(rw,sync,no_subtree_check) #for our training data
/home/guest     x.x.x.x/yy(rw,sync,no_subtree_check) #for a user to train on the cluster (specific to the horovod solution)
```
And we restart the nfs server:
```
sudo systemctl restart nfs-kernel-server
```

**Client side** : <div></div>
Installing the nfs client is done through:
```bash
sudo apt install nfs-common
```
We then mount permanently our nfs volume(s):
```bash
server_ip_address:/media/nfs	/media/share	nfs	defaults,user,exec	0 0
server_ip_address:/home/guest	/home/guest	nfs	defaults,user,exec	0 0
```
If they didn't mount right away after saving, execute `sudo mount -a`.

[¹] : Based on [this guide](https://linuxconfig.org/how-to-set-up-a-nfs-server-on-debian-10-buster).

## MPI 'cluster'
### Introduction
This configuration step is quite long (about 1h to 1h and a half for each jetson nano).
So before we get going, we need to choose between one of two ways to go about this cluster configuration :
- One way to go about it is to configure each jetson nano separately. To make this a bit easier you can use the option `setw synchronize-panes on` on `tmux` (open as many panes as you have jetson nanos, ssh to each one of them).
    - Side note on SSH : To make connecting to each board less of a hassle, you can generate a pair of keys for each one of them through `ssh-keygen -t rsa`. You can then create a file named `authorized_keys` in your nfs directory, copy your key into it (`echo id_rsa.pub >> /path/to/authorized_keys`). Finaly create a symbolic link between this file and your .ssh directory trhough `ln -s /path/to/authorized_keys /home/user_name/.ssh/authorized_keys`.
- The other way to go about it is to configure one board from start to finish and then clone either with balena etcher or through these steps :
    ```
    dd bs=4M if=/dev/sdcard of=/path/to/jetson-nano-clean.img
    dd bs=1M if=/path/to/jetson-nano-clean.img of=/dev/sdcard
    ```
The second solution is faster only if you can manage to clone everything at the same time. Otherwise the first one might be better.
Note that with the second solution you'll have a permanent 'clean' image stored on your disk for use later on, if you think that'll be useful for you go with the first solution.

### Installing Pytorch
All the steps described here are from [this Nvidia forum](https://forums.developer.nvidia.com/t/pytorch-for-jetson-version-1-9-0-now-available/72048).

**For the torch library** :
```bash
$ wget https://nvidia.box.com/shared/static/p57jwntv436lfrd78inwl7iml6p13fzh.whl -O torch-1.8.0-cp36-cp36m-linux_aarch64.whl
$ sudo apt-get install python3-pip libopenblas-base libopenmpi-dev 
$ pip3 install Cython
$ pip3 install numpy torch-1.8.0-cp36-cp36m-linux_aarch64.whl
```
**For the torchvision library** (this will take the longest time) :
```bash
$ sudo apt-get install libjpeg-dev zlib1g-dev libpython3-dev libavcodec-dev libavformat-dev libswscale-dev
$ git clone --branch v0.9.0 https://github.com/pytorch/vision torchvision
$ cd torchvision
$ export BUILD_VERSION=0.9.0  
$ python3 setup.py install --user
$ cd ../
$ pip install 'pillow<7'
```
You can then test both of the installation with the following steps :
```python
import torch
import torchvision
print(torch.cuda.get_device_properties(0))
print(torchvision.__version__)
```

### Installing Horovod
First of all we need to install some packages to avoid wheel build errors later on :
```bash
sudo apt install python-dev build-essential libssl-dev libffi-dev libxm12-dev libxslt1-dev zlib1g-dev python-pip
```
and then you should be able to install horovod without any hiccups :
```bash
pip3 install horovod
```

### Making the 'cluster' work
For horovod to communicate between all the 'nodes', they need to be able to ssh between one another through their pair of keys. So if you haven't done it already, go back up to the introduction of this part and share the public keys of each one of the board to another.

I've wrote a small bash script to make it easier to test the cluster :
```bash
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
```

>This file needs a little bit of context.
Since each 'node' has a dynamic ip and only the nfs server is static (in our case) I need to have a way to figure out which ip each one of my board has.
>
>So through a crontab that execute the following script on each board :
>```bash
>#!/bin/bash
>
>ip=$(/sbin/ifconfig eth0 | grep 'inet ' | cut -d' ' -f10)
>hostname=$(hostname)
>
>echo $hostname:$ip > /media/share/$hostname
>```
>and a simple crontab on the server that execute the following command :
>```bash
>/bin/cat /media/nfs/jetson* > /media/nfs/all_ips
>```
>I can have all of the ips of my boards on a single file that looks like the following :
>```
>jetson0-node:157.159.78.116
>jetson1-node:157.159.78.118
>jetson2-node:157.159.78.117
>jetson3-node:157.159.78.119
>```
>File that I go through in the script `run.sh`.

The first argument of the script is the number of 'node' I want the python script to be distributed on. The second one is the python file.

The option `--epochs` is specific to the files I used, which you can find on [this link](https://github.com/horovod/horovod/tree/master/examples/pytorch).

Now run the script, with for example the following command for 4 boards :
```bash
./run.sh 4 pytorch_mnist.py
```
If all went well you should see the training splitted between all of your boards and your results should display at the end.

If you run out of memory with an error `Cannot allocate memory` make sure that you have mounted all the swap storage that you have available.

It's also interesting to see how the resources of each board is affected by this which we can see through the `tegrastats` command. Here is a more compact version for more clarity :
```bash
tegrastats | cut -d' ' -f10,14,16,18
```
The first column is the CPU usage accross all 4 cores, the second is the GPU usage, the third the CPU temp and the last the GPU temp.
