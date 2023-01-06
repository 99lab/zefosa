#!/bin/bash

# Enable ssh into the host

echo PermitRootLogin yes >> /etc/ssh/sshd_config
systemctl restart sshd

# Install the users ssh key
USERSSHKEY=""

mkdir /root/.ssh
curl $USERSSHKEY -o /root/.ssh/authorized_keys

# Disable SELinux Temporarily
setenforce 0

# Install ZFS Repository, packages and requirements
dnf install -y https://zfsonlinux.org/fedora/zfs-release-2-2$(rpm --eval "%{dist}").noarch.rpm
dnf repolist --all
rpm -e --nodeps zfs-fuse

dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/$(source /etc/os-release; echo $VERSION_ID)/Everything/x86_64/os/Packages/k/kernel-devel-$(uname -r).rpm
dnf install -y zfs

modprobe zfs