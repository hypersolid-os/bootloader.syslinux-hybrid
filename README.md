hypersolid hybrid uefi/bios bootloader for baremetal systems
===================================================================

**boot hypersolid via syslinux efi+mbr**

Use [syslinux/syslinux](https://wiki.syslinux.org/wiki/index.php?title=syslinux) as bootloader to load hypersolid from removable devices.

Features
----------------------------

* hybrid boot support
* legacy/mbr mode
* efi mode
* dual system partitions (primary and backup)

How to deploy
----------------------------

Write the image directly to the device via `dd`

```bash
# extract image and write to disk
gzip -d -c boot.img.gz | dd bs=4M status=progress of=/dev/sdX

# create new uuid's and rewrite secondary GPT table to the end of the disk
sgdisk -G /dev/sdX && sync
```

Add system image
----------------------------

You can directly add the hypersolid kernel/initramfs/system images to the build by adding them into the `image/` directory. They are automatically copied into the final partition image. 

It can be used to create a rescue image.

```bash
image/
├── initramfs.img
├── kernel.img
└── system.img
```

Partition layout
----------------------------

The following GPT based partition layout is used (of course, syslinux can handle ext2 on gpt including legacy/mbr mode).

* Partition 1 "bootloader" - `50MB`  | `FAT32` | syslinux efi+legacy loader ons esp partition including kernel+initramfs(1)
* Partition 2 "system0"    - `2GB`   | `EXT4`  | hypersolid system0 partition including `system.img`
* Partition 3 "system1"    - `2GB`   | `EXT4`  | hypersolid system1 partition including `system.img`
* Partition 4 "conf"       - `512MB` | `EXT4`  | hypersolid persistent storage
* Partition 5 "swap"       - `4GB`   | `EXT4`  | swap (optional)
* Partition 6 "data"       - `XGB`   | `EXT4`  | persistent storage (optional)

Build the image
----------------------------

This bootloader-generator creates a raw GPT disk image with 4 paritions (boot, config) including all required bootloader files + configs. The build environment is isolated within a docker container but requires full system access (privileged mode) due to the use of loop devices.

Just run `build.sh` to build the docker image and trigger the image build script. The disk image will be copied into the `dist/` directory.

```txt
 $ ./build.sh 

```

Boot stages
----------------------------

### legacy bios/mbr ###

0. host system loads the initial bootloader (e.g. SeaBIOS) | hostsystem
1. BIOS loads the MBR bootcode (`gptmbr.bin`) at the start of the root disk | syslinux-stage1
2. syslinux mbr code searches for the first active partition | syslinux-stage1
3. syslinux mbr code executes the volume boot records of the active partition (contains the inode address of `ldlinux.sys`) | syslinux-stage2
4. syslinux loads the rest of `ldlinux.sys` | syslinux-stage3
5. syslinux loads `ldlinux.c32` core bootloader module | syslinux-stage4
6. syslinux core module searches for the configuration file `syslinux/syslinux.cfg` and loads it | syslinux-stage5
7. syslinux loads `kernel.img` and `initramfs.ing` into ramdisk | syslinux-stage6
7. syslinux executes the `kernel.img` code | kernel-stage1

### efi ###

0. host system loads the initial UEFI bootloader | hostsystem
1. EFI loader loads+executes syslinux image `efi/boot/bootx64.efi` | hostsystem
2. syslinux loads `ldlinux.e64` core bootloader module | syslinux-stage1
3. syslinux core module searches for the configuration file `efi/boot/syslinux.cfg` and loads it | syslinux-stage2
4. syslinux loads `kernel.img` and `initramfs.ing` into ramdisk | syslinux-stage3
5. syslinux executes the `kernel.img` code | kernel-stage1


Serial Console
----------------------------

To enable the serial console (syslinux bootloader + kernel) just add the `SERIAL` directive as first line to your syslinux config and append the `console` option the kernel options.

**Example**

```conf
SERIAL 0 115200
DEFAULT linux
    SAY [BIOS/MBR] - booting debian kernel from SYSLINUX...
LABEL linux
    KERNEL ../kernel.img
    APPEND root=PARTLABEL=system0 pstorage=PARTLABEL=rescue-conf ro console=tty0 console=ttyS0,115200n8
    INITRD ../initramfs.img

```

License
----------------------------

**hypersolid** is OpenSource and licensed under the Terms of [GNU General Public Licence v2](LICENSE.txt). You're welcome to [contribute](CONTRIBUTE.md)!