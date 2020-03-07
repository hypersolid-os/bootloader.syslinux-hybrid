#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

# Fail on Error !
set -e

export VIRTUAL_DISK=/tmp/disk.img

# container build ready - attach to interactive bash
if [ -f "/.buildready" ]; then
    # just start bash
    /bin/bash
    exit 0
else
    touch /.buildready
fi

# create mount point
mkdir -p /mnt/{bios,esp,system}

# Create sparse file to represent our disk
truncate --size 650M $VIRTUAL_DISK

# Create partition layout
# set "Legacy BIOS bootable flag" for boot parition (tag required by gptmbr.bin)
sgdisk --clear \
  --new 1::+50M   --typecode=1:ef00 --change-name=1:'efiboot' \
  --new 2::+50M    --typecode=2:8300 --change-name=2:'biosboot' --attributes=2:set:2 \
  --new 3::+512MB  --typecode=3:8300 --change-name=3:'system' \
  --new 4::-0      --typecode=4:8300 --change-name=4:'conf' \
  ${VIRTUAL_DISK}

# show layout
gdisk -l ${VIRTUAL_DISK}

# show additional attributes
sgdisk ${VIRTUAL_DISK} --attributes=2:show

# add mbr code
dd bs=440 count=1 conv=notrunc if=/usr/lib/EXTLINUX/gptmbr.bin of=${VIRTUAL_DISK}

# mount disk
LOOPDEV=$(losetup --find --show --partscan ${VIRTUAL_DISK})

# create filesystems
mkfs.vfat -F32 ${LOOPDEV}p1
mkfs.ext2 ${LOOPDEV}p2
mkfs.ext4 ${LOOPDEV}p3
mkfs.ext4 ${LOOPDEV}p4

# BIOS/MBR
# ---------------------------

# mount bios boot partition
mount ${LOOPDEV}p2 /mnt/bios

# create extlinux dir
mkdir -p /mnt/bios/syslinux

# initialize extlinux (stage2 volume boot record + files)
extlinux --install /mnt/bios/syslinux

# copy config files
cp /opt/conf/syslinux.bios.cfg /mnt/bios/syslinux/syslinux.cfg

# copy image files ?
if [ -f /opt/img/kernel.img ]; then
    cp /opt/img/kernel.img /mnt/bios
fi
if [ -f /opt/img/initramfs.img ]; then
    cp /opt/img/initramfs.img /mnt/bios
fi

# show files
tree /mnt/bios

# unmount
sync && umount /mnt/bios

# EFI
# ---------------------------

# mount efi partition
mount ${LOOPDEV}p1 /mnt/esp

# create syslinux dir
mkdir -p /mnt/esp/efi/boot

# copy efi loader
cp /usr/lib/SYSLINUX.EFI/efi64/syslinux.efi /mnt/esp/efi/boot/bootx64.efi
cp /usr/lib/syslinux/modules/efi64/ldlinux.e64 /mnt/esp/efi/boot/

# copy config files
cp /opt/conf/syslinux.efi.cfg /mnt/esp/efi/boot/syslinux.cfg

# copy image files ?
if [ -f /opt/img/kernel.img ]; then
    cp /opt/img/kernel.img /mnt/esp/efi
fi
if [ -f /opt/img/initramfs.img ]; then
    cp /opt/img/initramfs.img /mnt/esp/efi
fi

# show files
tree /mnt/esp

# unmount
sync && umount /mnt/esp

# System image
# ---------------------------

# copy image file ?
if [ -f /opt/img/system.img ]; then
    # mount system partition
    mount ${LOOPDEV}p3 /mnt/system

    # copy image
    cp /opt/img/system.img /mnt/system

    # show files
    tree /mnt/system

    # unmount
    sync && umount /mnt/system
fi

# Finish
# ---------------------------

# detach loop device
losetup --detach $LOOPDEV

# compress image
gzip ${VIRTUAL_DISK}
