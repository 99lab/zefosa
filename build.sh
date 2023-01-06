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

# Find and partition block devices

DISK=$(lsblk -pe 252 | sed -n '/disk/p' | awk '{ print $1 }' | xargs -I{} find -L /dev/disk/by-id/ -samefile {})

echo "installing to $DISK"

for i in ${DISK}; do

  sgdisk --zap-all $i

  sgdisk -n1:1M:+1G -t1:EF00 $i

  sgdisk -n2:0:0   -t2:BF00 $i

done

# Create ZFS datasets

zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -R /mnt \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=zstd \
    -O dnodesize=auto \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -O mountpoint=/ \
    rpool \
    mirror \
   $(for i in ${DISK}; do
      printf "$i-part2 ";
     done)

zfs create \
    -o canmount=off \
    -o mountpoint=none \
    -o org.zfsbootmenu:rootprefix="root=zfs:" \
    -o org.zfsbootmenu:commandline="ro quiet" \
    rpool/fedora

zfs create \
    -o canmount=noauto \
    -o mountpoint=/ \
    -o org.zfsbootmenu:rootprefix="root=zfs:" \
    -o org.zfsbootmenu:commandline="ro quiet" \
    rpool/fedora

    zfs mount rpool/fedora

zfs create \
    -o canmount=off \
    -o mountpoint=none \
    rpool/data

zfs create \
    -o canmount=on \
    -o mountpoint=/home \
    rpool/data/home

zfs create \
    -o canmount=off \
    -o mountpoint=/var \
    rpool/data/var

zfs create \
    -o canmount=on \
    rpool/data/var/log

# Prepare the EFI Partition

dnf install -y arch-install-scripts gdisk dosfstools

curl -o /root/refind.rpm https://ixpeering.dl.sourceforge.net/project/refind/0.13.3.1/refind-0.13.3.1-1.x86_64.rpm

for i in ${DISK}; do
 mkfs.vfat -n EFI ${i}-part1
 mkdir -p /mnt/boot/efis/${i##*/}-part1
 mount -t vfat ${i}-part1 /mnt/boot/efis/${i##*/}-part1
done

mkdir -p /mnt/boot/efi
mount -t vfat $(echo $DISK | cut -f1 -d\ )-part1 /mnt/boot/efi

dnf -y install /root/refind.rpm

wget -c https://github.com/zbm-dev/zfsbootmenu/releases/download/v2.1.0/zfsbootmenu-release-x86_64-v2.1.0.tar.gz -O /root/zbm.tgz

mkdir -p /boot/efi/EFI/zbm

tar -xf /root/zbm.tgz -C /boot/efi/EFI/zbm --strip=1 --no-same-owner

echo "\"Boot default\"  \"zfsbootmenu:POOL=rpool zbm.import_policy=hostid zbm.set_hostid zbm.timeout=5 ro quiet loglevel=0\"" >> /boot/efi/EFI/zbm/refind_linux.conf
echo "\"Boot to menu\"  \"zfsbootmenu:POOL=rpool zbm.import_policy=hostid zbm.set_hostid zbm.show ro quiet loglevel=0\"" >> /boot/efi/EFI/zbm/refind_linux.conf

# Install the base system

dnf --installroot=/mnt   --releasever=$(source /etc/os-release ; echo $VERSION_ID) -y install \
@core  kernel kernel-devel python3-dnf-plugin-post-transaction-actions

dnf --installroot=/mnt   --releasever=$(source /etc/os-release ; echo $VERSION_ID) -y install \
https://zfsonlinux.org/fedora/zfs-release-2-2$(rpm --eval "%{dist}").noarch.rpm

dnf --installroot=/mnt   --releasever=$(source /etc/os-release ; echo $VERSION_ID) -y install zfs zfs-dracut

mkdir -p /mnt/etc/
for i in ${DISK}; do
   echo UUID=$(blkid -s UUID -o value ${i}-part1) /boot/efis/${i##*/}-part1 vfat \
   umask=0022,fmask=0022,dmask=0022 0 1 >> /mnt/etc/fstab
done
echo $(echo $DISK | cut -f1 -d\ )-part1 /boot/efi vfat \
   noauto,umask=0022,fmask=0022,dmask=0022 0 1 >> /mnt/etc/fstab

echo 'add_dracutmodules+=" zfs "' > /mnt/etc/dracut.conf.d/zfs.conf

hwclock --systohc
systemctl enable systemd-timesyncd --root=/mnt

rm -f /mnt/etc/localtime
systemd-firstboot --root=/mnt --force --prompt --root-password=PASSWORD

zgenhostid -f -o /mnt/etc/hostid
dnf --installroot=/mnt install -y glibc-minimal-langpack glibc-langpack-en

systemctl enable zfs-import-scan.service zfs-import.target zfs-zed zfs.target zfs-mount --root=/mnt