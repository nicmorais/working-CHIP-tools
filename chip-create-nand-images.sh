#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/common.sh

if [[ -z $(which ${MKFS_UBIFS}) ]]; then
  echo "Could not find ${MKFS_UBIFS} in path."
  echo "Install it with the CHIP-SDK setup script."
  echo "You will also need to run this script as root."
  exit 1
fi

UBOOTDIR="$1"
ROOTFSTAR="$2"
OUTPUTDIR="$3"

# build the UBI image
prepare_ubi() {
  local tmpdir=`mktemp -d -t chip-ubi-XXXXXX`
  local rootfs=$tmpdir/rootfs
  local ubifs=$tmpdir/rootfs.ubifs
  local ubicfg=$tmpdir/ubi.cfg
  local outputdir="$1"
  local rootfstar="$2"
  local nandtype="$3"
  local maxlebcount="$4"
  local eraseblocksize="$5"
  local pagesize="$6"
  local subpagesize="$7"
  local oobsize="$8"
  local ebsize=`printf %x $eraseblocksize`
  local psize=`printf %x $pagesize`
  local osize=`printf %x $oobsize`
  local ubi=$outputdir/chip-$ebsize-$psize-$osize.ubi
  local sparseubi=$outputdir/chip-$ebsize-$psize-$osize.ubi.sparse
  local mlcopts=""

  if [ -z $subpagesize ]; then
    subpagesize=$pagesize
  fi

  if [ "$nandtype" = "mlc" ]; then
    lebsize=$((eraseblocksize/2-$pagesize*2))
    mlcopts="-M dist3"
  elif [ $subpagesize -lt $pagesize ]; then
    lebsize=$((eraseblocksize-pagesize))
  else
    lebsize=$((eraseblocksize-pagesize*2))
  fi
  
  if [ "$osize" = "100" ]; then
    #TOSH_512_SLC
    volspec="vol_flags=autoresize"
  elif [ "$osize" = "500" ]; then
    #TOSH_4GB_MLC
    volspec="vol_size=3584MiB"
  elif [ "$osize" = "680" ]; then
    #HYNI_8GB_MLC
    volspec="vol_size=7168MiB"
  else
	echo "Unable to acquire appropriate volume size or flags, quitting!"
	exit 1
  fi

  mkdir -p $rootfs
  tar -xf $rootfstar -C $rootfs
  ${MKFS_UBIFS} -d $rootfs -m $pagesize -e $lebsize -c $maxlebcount -o $ubifs
  echo "[rootfs]
mode=ubi
vol_id=0
$volspec
vol_type=dynamic
vol_name=rootfs
vol_alignment=1
image=$ubifs" > $ubicfg


  ubinize -o $ubi -p $eraseblocksize -m $pagesize -s $subpagesize $mlcopts $ubicfg
  img2simg $ubi $sparseubi $eraseblocksize
  rm -rf $tmpdir
}

# build the SPL image
prepare_spl() {
  local tmpdir=`mktemp -d -t chip-spl-XXXXXX`
  local outputdir=$1
  local spl=$2
  local eraseblocksize=$3
  local pagesize=$4
  local oobsize=$5
  local repeat=$((eraseblocksize/pagesize/64))
  local nandspl=$tmpdir/nand-spl.bin
  local nandpaddedspl=$tmpdir/nand-padded-spl.bin
  local ebsize=`printf %x $eraseblocksize`
  local psize=`printf %x $pagesize`
  local osize=`printf %x $oobsize`
  local nandrepeatedspl=$outputdir/spl-$ebsize-$psize-$osize.bin
  local padding=$tmpdir/padding
  local splpadding=$tmpdir/nand-spl-padding

  ${SNIB} -c 64/1024 -p $pagesize -o $oobsize -u 1024 -e $eraseblocksize -b -s $spl $nandspl

  local splsize=`filesize $nandspl`
  local paddingsize=$((64-(splsize/(pagesize+oobsize))))
  local i=0

  while [ $i -lt $repeat ]; do
    dd if=/dev/urandom of=$padding bs=1024 count=$paddingsize
    ${SNIB} -c 64/1024 -p $pagesize -o $oobsize -u 1024 -e $eraseblocksize -b -s $padding $splpadding
    cat $nandspl $splpadding > $nandpaddedspl

    if [ "$i" -eq "0" ]; then
      cat $nandpaddedspl > $nandrepeatedspl
    else
      cat $nandpaddedspl >> $nandrepeatedspl
    fi

    i=$((i+1))
  done

  rm -rf $tmpdir
}

# build the bootloader image
prepare_uboot() {
  local outputdir=$1
  local uboot=$2
  local eraseblocksize=$3
  local ebsize=`printf %x $eraseblocksize`
  local paddeduboot=$outputdir/uboot-$ebsize.bin

  dd if=$uboot of=$paddeduboot bs=$eraseblocksize conv=sync
}

## copy the source images in the output dir ##
mkdir -p $OUTPUTDIR
cp $UBOOTDIR/spl/sunxi-spl.bin $OUTPUTDIR/
cp $UBOOTDIR/u-boot-dtb.bin $OUTPUTDIR/
cp $ROOTFSTAR $OUTPUTDIR/

## prepare ubi images ##
# Toshiba SLC image:
prepare_ubi $OUTPUTDIR $ROOTFSTAR "slc" 2048 262144 4096 1024 256
# Toshiba MLC image:
prepare_ubi $OUTPUTDIR $ROOTFSTAR "mlc" 4096 4194304 16384 16384 1280
# Hynix MLC image:
prepare_ubi $OUTPUTDIR $ROOTFSTAR "mlc" 4096 4194304 16384 16384 1664

## prepare spl images ##
# Toshiba SLC image:
prepare_spl $OUTPUTDIR $UBOOTDIR/spl/sunxi-spl.bin 262144 4096 256
# Toshiba MLC image:
prepare_spl $OUTPUTDIR $UBOOTDIR/spl/sunxi-spl.bin 4194304 16384 1280
# Hynix MLC image:
prepare_spl $OUTPUTDIR $UBOOTDIR/spl/sunxi-spl.bin 4194304 16384 1664

## prepare uboot images ##
# Toshiba SLC image:
prepare_uboot $OUTPUTDIR $UBOOTDIR/u-boot-dtb.bin 262144
# Toshiba/Hynix MLC image:
prepare_uboot $OUTPUTDIR $UBOOTDIR/u-boot-dtb.bin 4194304
