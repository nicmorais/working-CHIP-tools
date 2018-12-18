#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/common.sh

##############################################################
#  main
##############################################################
while getopts "flpu:" opt; do
  case $opt in
    f)
      echo "fastboot enabled"
      METHOD=fastboot
      ;;
    l)
      echo "factory mode remain in u-boot after flashing"
      AFTER_FLASHING=loop
      ;;
    u)
      BUILDROOT_OUTPUT_DIR="${OPTARG}"
      ;;
    p)
      POCKET_CHIP=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

echo "BUILDROOT_OUTPUT_DIR = $BUILDROOT_OUTPUT_DIR"

FEL=fel

METHOD=${METHOD:-fel}
AFTER_FLASHING=${AFTER_FLASHING:-wait}


NAND_ERASE_BB=false
if [ "$1" == "erase-bb" ]; then
	NAND_ERASE_BB=true
fi

PATH=$PATH:$BUILDROOT_OUTPUT_DIR/host/usr/bin
TMPDIR=`mktemp -d -t chipflashXXXXXX`
PADDED_SPL="${BUILDROOT_OUTPUT_DIR}/images/sunxi-spl-with-ecc.bin"
PADDED_SPL_SIZE=0
UBOOT_SCRIPT="$TMPDIR/uboot.scr"
UBOOT_SCRIPT_MEM_ADDR=0x43100000
UBOOT_SCRIPT_SRC="$TMPDIR/uboot.cmds"
SPL="$BUILDROOT_OUTPUT_DIR/images/sunxi-spl.bin"
SPL_MEM_ADDR=0x43000000
UBOOT="$BUILDROOT_OUTPUT_DIR/images/u-boot-dtb.bin"
PADDED_UBOOT="$TMPDIR/padded-uboot"
PADDED_UBOOT_SIZE=0x400000
UBOOT_MEM_ADDR=0x4a000000
UBI="$BUILDROOT_OUTPUT_DIR/images/rootfs.ubi"
SPARSE_UBI="${TMPDIR}/rootfs.ubi.sparse"
UBI_MEM_ADDR=0x4b000000

UBI_SIZE=`filesize $UBI | xargs printf "0x%08x"`
PAGE_SIZE=16384
OOB_SIZE=1664

prepare_images() {
  #PADDED_SPL_SIZE in pages
  if [[ ! -e "${PADDED_SPL}" ]]; then
    echo "ERROR: can not read ${PADDED_SPL}"
    exit 1
  fi

	PADDED_SPL_SIZE=$(filesize "${PADDED_SPL}")
  PADDED_SPL_SIZE=$(($PADDED_SPL_SIZE / ($PAGE_SIZE + $OOB_SIZE)))
  PADDED_SPL_SIZE=$(echo $PADDED_SPL_SIZE | xargs printf "0x%08x")
  echo "PADDED_SPL_SIZE=$PADDED_SPL_SIZE"

	# Align the u-boot image on a page boundary
	dd if="$UBOOT" of="$PADDED_UBOOT" bs=4M conv=sync
	UBOOT_SIZE=`filesize "$PADDED_UBOOT" | xargs printf "0x%08x"`
  echo "UBOOT_SIZE=${UBOOT_SIZE}"
  echo "PADDED_UBOOT_SIZE=${PADDED_UBOOT_SIZE}"
	dd if=/dev/urandom of="$PADDED_UBOOT" seek=$((UBOOT_SIZE / 0x4000)) bs=16k count=$(((PADDED_UBOOT_SIZE - UBOOT_SIZE) / 0x4000))
}

prepare_uboot_script() {
	if [ "$NAND_ERASE_BB" = true ] ; then
		echo "nand scrub -y 0x0 0x200000000" > "${UBOOT_SCRIPT_SRC}"
	else
		echo "nand erase 0x0 0x200000000" > "${UBOOT_SCRIPT_SRC}"
	fi

	echo "echo nand write.raw.noverify $SPL_MEM_ADDR 0x0 $PADDED_SPL_SIZE" >> "${UBOOT_SCRIPT_SRC}"
	echo "nand write.raw.noverify $SPL_MEM_ADDR 0x0 $PADDED_SPL_SIZE" >> "${UBOOT_SCRIPT_SRC}"
	echo "echo nand write.raw.noverify $SPL_MEM_ADDR 0x400000 $PADDED_SPL_SIZE" >> "${UBOOT_SCRIPT_SRC}"
	echo "nand write.raw.noverify $SPL_MEM_ADDR 0x400000 $PADDED_SPL_SIZE" >> "${UBOOT_SCRIPT_SRC}"

	echo "nand write $UBOOT_MEM_ADDR 0x800000 $PADDED_UBOOT_SIZE" >> "${UBOOT_SCRIPT_SRC}"
	echo "setenv bootargs root=ubi0:rootfs rootfstype=ubifs rw earlyprintk ubi.mtd=4" >> "${UBOOT_SCRIPT_SRC}"
	echo "setenv bootcmd 'gpio set PB2; if test -n \${fel_booted} && test -n \${scriptaddr}; then echo '(FEL boot)'; source \${scriptaddr}; fi; mtdparts; ubi part UBI; ubifsmount ubi0:rootfs; ubifsload \$fdt_addr_r /boot/sun5i-r8-chip.dtb; ubifsload \$kernel_addr_r /boot/zImage; bootz \$kernel_addr_r - \$fdt_addr_r'" >> "${UBOOT_SCRIPT_SRC}"
  echo "setenv fel_booted 0" >> "${UBOOT_SCRIPT_SRC}"

  echo "echo Enabling Splash" >> "${UBOOT_SCRIPT_SRC}"
  echo "setenv stdout serial" >> "${UBOOT_SCRIPT_SRC}"
  echo "setenv stderr serial" >> "${UBOOT_SCRIPT_SRC}"
  echo "setenv splashpos m,m" >> "${UBOOT_SCRIPT_SRC}"

  echo "echo Configuring Video Mode"
  if [[ "${POCKET_CHIP}" == "true" ]]; then
    echo "setenv video-mode" >> "${UBOOT_SCRIPT_SRC}"
  else
    echo "setenv video-mode sunxi:640x480-24@60,monitor=composite-ntsc,overscan_x=40,overscan_y=20" >> "${UBOOT_SCRIPT_SRC}"
  fi

  echo "saveenv" >> "${UBOOT_SCRIPT_SRC}"

  if [[ "${METHOD}" == "fel" ]]; then
	  echo "nand write.slc-mode.trimffs $UBI_MEM_ADDR 0x1000000 $UBI_SIZE" >> "${UBOOT_SCRIPT_SRC}"
	  echo "mw \${scriptaddr} 0x0" >> "${UBOOT_SCRIPT_SRC}"
  else
    echo "echo going to fastboot mode" >>"${UBOOT_SCRIPT_SRC}"
    echo "fastboot 0" >>"${UBOOT_SCRIPT_SRC}"
  fi

  if [[ "${AFTER_FLASHING}" == "boot" ]]; then
    echo "echo " >>"${UBOOT_SCRIPT_SRC}"
    echo "echo *****************[ BOOT ]*****************" >>"${UBOOT_SCRIPT_SRC}"
    echo "echo " >>"${UBOOT_SCRIPT_SRC}"
    echo "boot" >> "${UBOOT_SCRIPT_SRC}"
  else
    echo "echo " >>"${UBOOT_SCRIPT_SRC}"
    echo "echo *****************[ FLASHING DONE ]*****************" >>"${UBOOT_SCRIPT_SRC}"
    echo "echo " >>"${UBOOT_SCRIPT_SRC}"
    if [[ "${METHOD}" == "fel" ]]; then
      echo "reset"
    else
      echo "while true; do; sleep 10; done;" >>"${UBOOT_SCRIPT_SRC}"
    fi
  fi

	mkimage -A arm -T script -C none -n "flash CHIP" -d "${UBOOT_SCRIPT_SRC}" "${UBOOT_SCRIPT}"
}

assert_error() {
	ERR=$?
	ERRCODE=$1
	if [ "${ERR}" != "0" ]; then
		if [ -z "${ERR}" ]; then
			exit ${ERR}
		else
			exit ${ERRCODE}
		fi
	fi
}

echo == preparing images ==
prepare_images
prepare_uboot_script

echo == upload the SPL to SRAM and execute it ==
if ! wait_for_fel; then
  echo "ERROR: please make sure CHIP is connected and jumpered in FEL mode"
fi
${FEL} spl "${SPL}"
assert_error 128

sleep 1 # wait for DRAM initialization to complete

echo == upload spl ==
${FEL} write $SPL_MEM_ADDR "${PADDED_SPL}" || ( echo "ERROR: could not write ${PADDED_SPL}" && exit $? )
assert_error 129

echo == upload u-boot ==
${FEL} write $UBOOT_MEM_ADDR "${PADDED_UBOOT}" || ( echo "ERROR: could not write ${PADDED_UBOOT}" && exit $? )
assert_error 130

echo == upload u-boot script ==
${FEL} write $UBOOT_SCRIPT_MEM_ADDR "${UBOOT_SCRIPT}" || ( echo "ERROR: could not write ${UBOOT_SCRIPT}" && exit $? )
assert_error 131

if [[ "${METHOD}" == "fel" ]]; then
	echo == upload ubi ==
	${FEL} --progress write $UBI_MEM_ADDR "${UBI}"

	echo == execute the main u-boot binary ==
	${FEL} exe $UBOOT_MEM_ADDR

	echo == write ubi ==
else
	echo == execute the main u-boot binary ==
	${FEL} exe $UBOOT_MEM_ADDR
	assert_error 132

	echo == creating sparse image ==
	img2simg ${UBI} ${SPARSE_UBI} $((2*1024*1024))
	assert_error 133

	echo == waiting for fastboot ==
	if wait_for_fastboot; then
		fastboot -i 0x1f3a -u flash UBI ${SPARSE_UBI}
		assert_error 134

		fastboot -i 0x1f3a continue
		assert_error 135
	else
		rm -rf "${TMPDIR}"
		exit 1
	fi
fi

if [[ "${METHOD}" == "fel" ]]; then
	if ! wait_for_linuxboot; then
		echo "ERROR: could not flash":
		rm -rf ${TMPDIR}
		exit 1
	else
		${SCRIPTDIR}/verify.sh
	fi
fi
rm -rf "${TMPDIR}"

ready_to_roll

