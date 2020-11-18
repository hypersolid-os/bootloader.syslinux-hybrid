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
truncate --size 2650M $VIRTUAL_DISK

# Create partition layout
# set "Legacy BIOS bootable flag" for boot parition (tag required by gptmbr.bin)
sgdisk --clear \
  --new 1::+50M   --typecode=1:ef00 --change-name=1:"${PARTNAME_PREFIX}bootloader" --attributes=1:set:2\
  --new 2::+1G     --typecode=2:8300 --change-name=2:"${PARTNAME_PREFIX}system0" \
  --new 3::+1G     --typecode=3:8300 --change-name=3:"${PARTNAME_PREFIX}system1" \
  --new 4::-0      --typecode=4:8300 --change-name=4:"${PARTNAME_PREFIX}conf" \
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
mkfs.ext4 ${LOOPDEV}p2
mkfs.ext4 ${LOOPDEV}p3
mkfs.ext4 ${LOOPDEV}p4

# BIOS/MBR + EFI Bootloader
# ---------------------------

# mount efi partition
mount ${LOOPDEV}p1 /mnt/esp

# create extlinux dir
mkdir -p /mnt/esp/syslinux

# create syslinux dir
mkdir -p /mnt/esp/efi/boot

# create kernel+initramfs storage dirs
mkdir -p /mnt/esp/{sys0,sys1}

# initialize extlinux (stage2 volume boot record + files)
extlinux --install /mnt/esp/syslinux

# copy config files
cp /opt/conf/syslinux.bios.cfg /mnt/esp/syslinux/syslinux.cfg

# copy efi loader
cp /usr/lib/SYSLINUX.EFI/efi64/syslinux.efi /mnt/esp/efi/boot/bootx64.efi
cp /usr/lib/syslinux/modules/efi64/ldlinux.e64 /mnt/esp/efi/boot/

# copy config files
cp /opt/conf/syslinux.efi.cfg /mnt/esp/efi/boot/syslinux.cfg

# copy image files ?
if [ -f /opt/img/kernel.img ]; then
    cp /opt/img/kernel.img /mnt/esp/sys0
fi
if [ -f /opt/img/initramfs.img ]; then
    cp /opt/img/initramfs.img /mnt/esp/sys0
fi

# show files
tree /mnt/esp

# unmount
sync && umount /mnt/esp

# System image
# ---------------------------

# copy image file ?
if [ -f /opt/img/system.img ]; then
    echo "copying system image.."

    # mount system partition
    mount ${LOOPDEV}p3 /mnt/system

    # copy image
    cp /opt/img/system.img /mnt/system

    # show files
    tree /mnt/system

    # unmount
    sync && umount /mnt/system

    echo "- done"
fi

# Finish
# ---------------------------

# detach loop device
losetup --detach $LOOPDEV

# compress image
echo "compressing disk image.."
gzip ${VIRTUAL_DISK} && {
    echo "- done"
}
cp ${VIRTUAL_DISK}.gz /tmp/dist/
