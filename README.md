Forked from https://gist.github.com/danidiaz/4486be84912ab71a9802

## Server Preparation

On OVH, you'll have a main partition and an home one over LVM. You should create a partition for docker volumes because they can become too big for the main partition.

```
cd /
sudo -i
systemctl stop docker
umount /home
e2fsck -ff /dev/vg/home
resize2fs /dev/vg/home 40G
lvreduce -L 40G /dev/vg/home
lvcreate -l 100%FREE -n docker vg
mkfs.ext4 /dev/vg/docker
mv /var/lib/docker /var/lib/__docker
chmod --reference=/var/lib/__docker/ /var/lib/docker
vi /etc/fstab
    /dev/vg/docker  /var/lib/docker ext4    defaults        1       2
mount -a
mount | column -t
mv /var/lib/__docker/* /var/lib/docker/
systemctl start docker
```

## Prerequisites:

1) Copy your ssh pubkey in /root/.ssh/authorized_keys
2) Configure contants bellow

## How to run this script

1) su -
2) cd /root
3) git clone https://github.com/Honiix/linux-post-install.git
4) cp config-default.sh config.sh
5) edit config.sh
6) chmod u+x centos7-postinstall.sh
7) ./centos7-postinstall.sh


After this script you should:

1) Change root password
2) Change $USERNAME password
