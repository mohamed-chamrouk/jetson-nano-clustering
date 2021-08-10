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
    ssh -tt root@$host 'usermod -aG sudo $1' < /dev/null
    ssh -tt root@host 'cat /media/Share/fstab.txt >> /etx/fstab' < /dev/null
    ssh -tt root]$host 'mount -a' < /dev/null
done < all_ips