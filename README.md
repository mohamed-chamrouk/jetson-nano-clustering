# Jetson Nano Clustering

## Quick Introduction

This project was made in collaboration with [Télécom SudParis](https://www.telecom-sudparis.eu/) for a cost-efficient solution for machine learning model training.

Although meant to be used with the python library [Pytorch](https://pytorch.org/), [TensorFlow](www.tensorflow.org) and [Horovod](https://horovod.ai/) the cluster can, of course, be adapted for the use of other libraries (although this means that you will have to debug any issue yourself).

Now for the cluster, there are two ways though which we explored it :
- Clustering through MPI : MPI or Message Passing Interface is a standard meant for distributed applications. This standard is here used through Horovod.
    - Benefits : Easy to understand and implement.
    - Drawbacks : Long configuration time, limitations for resources.
- Clustering through kubernetes : Pretty self-explanatory, kubernetes allows us to create a cluster with a simple architecture of master-workers.
    - Benefits : Easy to configure, easily scalable, good use of resources.
    - Drawbacks : One node is "lost" as a master, configuration can be hard when needing specific libraries.
    > :warning: Kubernetes isn't meant for this type of use case. Kubeflow through the MPI Training operator or more simply horovod can be used for that task. We'll see later on how this affects performance compared to the bare-bone solution.
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
- 8 high speed sd card (we used 100Mbit/s 128Gb SD Card, but it's a bit overkill. Favor speed/endurance in spite of storage space)
- 1 gigabit network switch
- A server for storage (NFS in our case)
<div></div>

First and foremost, and this is true in general for jetson nano developer kits :
### First boot
This is fairly straight forward, there is a [complete guide](https://developer.nvidia.com/embedded/learn/get-started-jetson-nano-devkit#next) on Nvidia's website for how to setup a jetson nano.
> :warning: For the MPI/horovod 'cluster' you need to have a swap partition, so right before the end of the configuration, when you get asked how much you want to leave for disk space, remove 4gb to 8gb from it.

> :information_source: Small optional tip : It's best to configure well your hostnames and password during this step. It's a real hassle figuring things out later on so the sooner the better.

As mentioned in the *Nota Bene* section, you have to do this with every single one of your jetson nanos regardless of the way you choose to setup your cluster.

Although simple this part is the one that probably will take you the most amount of time. SD Cards are flash storage, so not terribly fast.

### Networking
In our case, every jetson nano had a public IP address making the configuration easier. However it's best practice to have static local addresses for each jetson nano. One way to do that is through routing on (for instance) the nfs server. By setting up a NAT on this server and connecting the switch to it, it will allow each jetson nano to have a local address while still being able to access internet.

If you want to setup NAT routing on your server follow these steps (from [here](https://how-to.fandom.com/wiki/How_to_set_up_a_NAT_router_on_a_Linux-based_computer)) :
- On the NAT server :
    - ```bash
      ip addr add 192.168.0.1/24 dev your_interface
      ```
    - ```bash
      modprobe iptable_nat
      echo 1 > /proc/sys/net/ipv4/ip_forward
      iptables -t nat -A POSTROUTING -o your_interface -j MASQUERADE
      iptables -A FORWARD -i second_interface -j ACCEPT
      ```
- On each of the clients :
    - ```bash
      ip addr add 192.168.0.x/24 dev your_interface
      ```
    - ```bash
      route add default gw 192.168.0.1/24
      ```
    - change `/etc/resolv.conf` to match the one of your server or to the one of your choic.

### NFS Server
Based on [this guide](https://linuxconfig.org/how-to-set-up-a-nfs-server-on-debian-10-buster).

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
The second solution is faster only if you can manage to clone everything at the same time. Otherwise, the first one might be better.
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

### Installing TensorFlow

Full guide available [here](https://docs.nvidia.com/deeplearning/frameworks/install-tf-jetson-platform/index.html).

Install system packages required by TensorFlow:
```bash
$ sudo apt-get update
$ sudo apt-get install libhdf5-serial-dev hdf5-tools libhdf5-dev zlib1g-dev zip libjpeg8-dev liblapack-dev libblas-dev gfortran
```
Install and upgrade pip3.
```bash
$ sudo apt-get install python3-pip
$ sudo pip3 install -U pip testresources setuptools==49.6.0 
```
Install the Python package dependencies.
```bash
$ sudo pip3 install -U numpy==1.19.4 future==0.18.2 mock==3.0.5 h5py==2.10.0 keras_preprocessing==1.1.1 keras_applications==1.0.8 gast==0.2.2 futures protobuf pybind11
```
Install tensorflow
```bash
$ sudo pip3 install --extra-index-url https://developer.download.nvidia.com/compute/redist/jp/v$JP_VERSION tensorflow==$TF_VERSION+nv$NV_VERSION
```
Where:
- **JP_VERSION**
  The major and minor version of JetPack you are using, such as 42 for JetPack 4.2.2 or 33 for JetPack 3.3.1.
- **TF_VERSION**
  The released version of TensorFlow, for example, 1.13.1.
- **NV_VERSION**
  The monthly NVIDIA container version of TensorFlow, for example, 19.01.

### Installing Horovod
First of all we need to install some packages to avoid wheel build errors later on :
```bash
sudo apt install python-dev build-essential libssl-dev libffi-dev libxm12-dev libxslt1-dev zlib1g-dev python-pip
pip3 install -U Cython
pip3 install -U testresources setuptools
```
and then you should be able to install horovod without any hiccups :
```bash
pip3 install horovod[tensorflow,pytorch] --no-deps
```
> The '--no-deps' option is here so that we avoid to download unnecessary dependencies. However if your install fails try removing the option.
### Making the 'cluster' work
For horovod to communicate between all the 'nodes', they need to be able to ssh between one another through their pair of keys. So if you haven't done it already, go back up to the introduction of this part and share the public keys of each one of the board to another.

I've written a small bash script to make it easier to test the cluster :
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

>>This file needs a bit of context.
Since each 'node' has a dynamic ip and only the nfs server is static (in our case) I need to have a way to figure out which ip each one of my board has.
>>
>>So through a crontab that execute the following script on each board :
>>```bash
>>#!/bin/bash
>>
>>ip=$(/sbin/ifconfig eth0 | grep 'inet ' | cut -d' ' -f10)
>>hostname=$(hostname)
>>
>>echo $hostname:$ip > /media/share/$hostname
>>```
>>and a simple crontab on the server that execute the following command :
>>```bash
>>/bin/cat /media/nfs/jetson* > /media/nfs/all_ips
>>```
>>I can have all the ips of my boards on a single file that looks like the following :
>>```
>>jetson0-node:157.159.78.116
>>jetson1-node:157.159.78.118
>>jetson2-node:157.159.78.117
>>jetson3-node:157.159.78.119
>>```
>>File that I go through in the script `run.sh`.
><div></div>
>:stop_sign: This no longer holds true. The current architecture uses static local ip addresses through a NAT. However we kept the same file and syntax to make it easier to add boards in the future.

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
The first column is the CPU usage across all 4 cores, the second is the GPU usage, the third the CPU temp and the last the GPU temp.

## Kubernetes cluster

### Preparing the boards
The first part of this guide is based on [this guide](https://medium.com/jit-team/building-a-gpu-enabled-kubernets-cluster-for-machine-learning-with-nvidia-jetson-nano-7b67de74172a).
> :information_source: Here again, it's best pratice and almost necessary to have static ip addresses. Therefore I highly recommend you follow the guide under *Networking* up in the guide.

Once you have done the first boot of every jetson nano we can start installing kubernetes on evry one of them.

First of all, on every board execute the following commands :
```bash
sudo systemctl set-default multi-user.target #to disable graphical interface
sudo nvpmodel -m 0 #high-power mode
sudo swapoff -a #disable swap, necessary on every reboot
```
Next set the `/etc/docker/daemon.json` file to :
```json
{
  “default-runtime”: “nvidia”,
  “runtimes”: {
    “nvidia”: {
      “path”: “nvidia-container-runtime”,
      “runtimeArgs”: []
     }
   }
}
```
And finally :
```bash
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```

Before going any further, it's safer testing now the gpu support for docker with the following docker image :
```bash
docker run -it jitteam/devicequery ./deviceQuery
```
Which should produce an output that ends with :
```bash
Driver Version = 10.0, CUDA Runtime Version = 10.0, NumDevs = 1Result = PASS
```
### Setting up Kubernetes
Execute the following commands on every board:
```bash
sudo apt-get install apt-transport-https -y
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni
```

### Master node

>:information_source: Note that if you haven't done it yet, you'll probably need to have noted somewhere the ip addresses of each board and its role in the cluster.

<div></div>

Launch the following command on the **sole master node** :
```bash
sudo kubeadm init --pod-network-cidr=10.244.10.0/16
```
It will produce an output with commands to follow to spread your cluster.

### Finishing the cluster

Once everything has been set up, test your cluster with the command :
```bash
kubectl get nodes
```
And troubleshoot any eventual issue your cluster may have faced before going on.
Now name each one of your nodes :
```bash
kubectl label node name_of_node1 node-role.kubernetes.io/worker=worker
kubectl label node name_of_node2 node-role.kubernetes.io/worker=worker
kubectl label node name_of_node3 node-role.kubernetes.io/worker=worker
```

### Testing for GPU Support inside the cluster

Now let's create our first pod with the following `gpu-test?yml` file :
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: devicequery
spec:
  containers:
    - name: nvidia
      image: jitteam/devicequery:latest
      command: [ "./deviceQuery" ]
```
And then type the following commands :
```bash
kubectl apply -f gpu-test.yml
kubectl logs devicequery
```
The output should be the same as with the docker image from before, if not troubleshooting is necessary.

### Requesting ressources from multiples nodes

As mentionned before, k8s isn't meant to be used in that kind of application. However that doesn't mean it's impossible or unefficient.

The first thing we'll need to do is to build our docker image with everything we need (we are basically making a container out of our previous environment).
Conveniently enough, nvidia made available a docker image with cuda, torch and torchvision installed easing our task :
```docker
FROM nvcr.io/nvidia/l4t-pytorch:r32.5.0-pth1.7-py3
RUN apt-get update -y
RUN apt-get install python3-pip libopenblas-base libopenmpi-dev -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install libhdf5-serial-dev hdf5-tools libhdf5-dev zlib1g-dev zip libjpeg8-dev liblapack-dev libblas-dev gfortran -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install python3 python-dev python3-dev build-essential libssl-dev libffi-dev libxml2-dev libxslt1-dev zlib1g-dev python-pip cmake openssh-client openssh-server -yq
RUN pip3 install -U Cython
RUN pip3 install -U testresources setuptools
RUN pip3 install horovod --no-cache-dir
```
Now build an image out of this file with :
```bash
docker build -t nvidia/torch-horovod -f Dockerfile .
```
And run a bash terminal inside of it with :
```bash
docker run -ti --rm --runtime nvidia nvidia/torch-horovod
```

If everything went well you should be able to execute to following commands without any error :
```
horovodrun -np 1 python3 -c "import torch; print(torch.cuda.get_device_properties(0))"
```