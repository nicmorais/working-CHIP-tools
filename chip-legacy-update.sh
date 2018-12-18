#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/common.sh

if ! wait_for_fel; then
  echo "ERROR: please jumper your CHIP in FEL mode then power on"
  exit 1
fi


FLASH_SCRIPT=./chip-fel-flash.sh
WHAT=buildroot
BRANCH=stable

function require_directory {
  if [[ ! -d "${1}" ]]; then
    mkdir -p "${1}"
  fi
}

function s3_md5 {
  local URL=$1
  curl -sLI $URL |grep ETag|sed -e 's/.*"\([a-fA-F0-9]\+\)["-]*.*/\1/;'
}

function cache_download {
  local DEST_DIR=${1}
  local SRC_URL=${2}
  local FILE=${3}

  if [[ -f "${DEST_DIR}/${FILE}" ]]; then
    echo "${DEST_DIR}/${FILE} exists... comparing to ${SRC_URL}/${FILE}"
    local S3_MD5=$(s3_md5 ${SRC_URL}/${FILE})
    local MD5=$(md5sum ${DEST_DIR}/${FILE} | cut -d\  -f1)
    echo "MD5: ${MD5}"
    echo "S3_MD5: ${S3_MD5}"
    if [[ "${S3_MD5}" != "${MD5}" ]]; then
      echo "md5sum differs"
      rm ${DEST_DIR}/${FILE}
      if ! wget -P "${FW_IMAGE_DIR}" "${SRC_URL}/${FILE}"; then
        echo "download of ${SRC_URL}/${FILE} failed!"
        exit $?
      fi 
    else
      echo "file already downloaded"
    fi
  else
    if ! wget -P "${FW_IMAGE_DIR}" "${SRC_URL}/${FILE}"; then
      echo "download of ${SRC_URL}/${FILE} failed!"
      exit $?
    fi 
  fi
}
    

while getopts "ufdpb:w:B:" opt; do
  case $opt in
    u)
      echo "updating cache"
      if [[ -d "$FW_IMAGE_DIR" ]]; then
        rm -rf $FW_IMAGE_DIR
      fi
      ;;
    f)
      echo "fastboot enabled"
      FLASH_SCRIPT_OPTION="-f"
      ;;
    B)
      BUILD="$OPTARG"
      echo "BUILD = ${BUILD}"
      ;;
    b)
      BRANCH="$OPTARG"
      echo "BRANCH = ${BRANCH}"
      ;;
    w)
      WHAT="$OPTARG"
      echo "WHAT = ${WHAT}"
      ;;
    d)
      echo "debian selected"
      WHAT="debian"
      ;;
    p)
      echo "PocketC.H.I.P selected"
      WHAT="pocketchip"
      BUILD=123
      FLASH_SCRIPT=./chip-fel-flash.sh -p
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done


FW_DIR="$(pwd)/.firmware"
FW_IMAGE_DIR="${FW_DIR}/images"
BASE_URL="http://chip.jfpossibilities.com/chip"
S3_URL="${BASE_URL}/${WHAT}/${BRANCH}/latest"



if [[ -z "$BUILD" ]]; then
  ROOTFS_URL="$(wget -q -O- ${S3_URL})" || (echo "ERROR: cannot reach ${S3_URL}" && exit 1)
  if [[ -z "${ROOTFS_URL}" ]]; then
    echo "error: could not get URL for latest build from ${S3_URL} - check internet connection"
    exit 1
  fi
else
  ROOTFS_URL="${S3_URL%latest}$BUILD"
fi

case "${WHAT}" in
  "buildroot")
    BR_BUILD="$(wget -q -O- ${ROOTFS_URL}/build)"
    BUILD=${BR_BUILD}
    ROOTFS_URL="${ROOTFS_URL}/images"
    BR_URL="${ROOTFS_URL}"
    ;;
  "debian")
    BR_BUILD="$(wget -q -O- ${ROOTFS_URL}/br_build)"
    BR_URL="${BASE_URL}/buildroot/${BRANCH%-gui}/${BR_BUILD}/images"
    BUILD="$(wget -q -O- ${ROOTFS_URL}/build)"
    ;;
  "pocketchip")
    BR_BUILD=123
    BUILD=123
    ROOTFS_URL="http://chip.jfpossibilities.com/chip/debian/pocketchip/"
    BR_URL="$ROOTFS_URL"
    ;;
esac 

echo "ROOTFS_URL=${ROOTFS_URL}"
echo "BUILD=${BUILD}"
echo "BR_URL=${BR_URL}"
echo "BR_BUILD=${BR_BUILD}"

require_directory "${FW_IMAGE_DIR}"
cache_download "${FW_IMAGE_DIR}" ${ROOTFS_URL} rootfs.ubi
cache_download "${FW_IMAGE_DIR}" ${BR_URL} sun5i-r8-chip.dtb
cache_download "${FW_IMAGE_DIR}" ${BR_URL} sunxi-spl.bin
cache_download "${FW_IMAGE_DIR}" ${BR_URL} sunxi-spl-with-ecc.bin
cache_download "${FW_IMAGE_DIR}" ${BR_URL} uboot-env.bin
cache_download "${FW_IMAGE_DIR}" ${BR_URL} zImage
cache_download "${FW_IMAGE_DIR}" ${BR_URL} u-boot-dtb.bin

BUILDROOT_OUTPUT_DIR="${FW_DIR}" ${FLASH_SCRIPT} ${FLASH_SCRIPT_OPTION} || echo "ERROR: could not flash" && exit 1

#if ! wait_for_linuxboot; then
#  echo "ERROR: could not flash"
#  exit 1
#else
#  ${SCRIPTDIR}/verify.sh
#fi

exit $?
