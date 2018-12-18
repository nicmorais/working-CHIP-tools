#! /bin/bash

SPL=$1
UBOOT=$2
KERNEL=$3
DTB=$4
INITRD=$5
SCRIPT=$6

echo == upload the SPL to SRAM and execute it ==
fel spl $SPL

sleep 1 # wait for DRAM initialization to complete

echo == upload the main u-boot binary to DRAM ==
fel write 0x4a000000 $UBOOT

echo == upload the kernel ==
fel write 0x42000000 $KERNEL

echo == upload the DTB file ==
fel write 0x43000000 $DTB

echo == upload the boot.scr file ==
fel write 0x43100000 $SCRIPT

echo == upload the initramfs file ==
fel write 0x43300000 $INITRD

echo == execute the main u-boot binary ==
fel exe   0x4a000000
