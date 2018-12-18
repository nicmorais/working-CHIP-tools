#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/common.sh

DL_DIR=".dl"
IMAGESDIR=".new/firmware/images"

DL_URL="http://chip.jfpossibilities.com/chip/images/"

WGET="wget"

FLAVOR=server
BRANCH=stable

PROBES=(spl-40000-1000-100.bin
 spl-400000-4000-500.bin
 spl-400000-4000-680.bin
 sunxi-spl.bin
 u-boot-dtb.bin
 uboot-40000.bin
 uboot-400000.bin)

UBI_PREFIX="chip"
UBI_SUFFIX="ubi.sparse"
UBI_TYPE="400000-4000-680"

while getopts "sgpbfnrhB:N:F:L:" opt; do
  case $opt in
    s)
      echo "== Server selected =="
      FLAVOR=server
      ;;
    g)
      echo "== Gui selected =="
      FLAVOR=gui
      ;;
    p)
      echo "== Pocketchip selected =="
      FLAVOR=pocketchip
      ;;
    b)
      echo "== Buildroot selected =="
      FLAVOR=buildroot
      ;;
    f)
      echo "== Force clean and download =="
      rm -rf .dl/ .new/
      ;;
    n)
      echo "== No Limit mode =="
      NO_LIMIT="while itest.b *0x80400000 -ne 03; do i2c mw 0x34 0x30 0x03; i2c read 0x34 0x30 1 0x80400000; done; "
      ;;
    r)
      echo "== Reset after flash =="
      RESET_COMMAND="reset"
      ;;
    B)
      BRANCH="$OPTARG"
      echo "== ${BRANCH} branch selected =="
      ;;
    N)
      CACHENUM="$OPTARG"
      echo "== Build number ${CACHENUM} selected =="
      ;;
    F)
      FORMAT="$OPTARG"
      echo "== Format ${FORMAT} selected =="
      ;;
    L)
      LOCALDIR="$OPTARG"
      echo "== Local directory '${LOCALDIR}' selected =="
      ;;
    h)
      echo ""
      echo "== Help =="
      echo ""
      echo "  -s  --  Server             [Debian + Headless]        "
      echo "  -g  --  GUI                [Debian + XFCE]            "
      echo "  -p  --  PocketCHIP         [CHIP on the go!]          "
      echo "  -b  --  Buildroot          [Tiny, but powerful]       "
      echo "  -f  --  Force clean        [re-download if applicable]"
      echo "  -n  --  No limit           [enable greater power draw]"
      echo "  -r  --  Reset              [reset device after flash] "
      echo "  -B  --  Branch             [eg. -B testing]           "
      echo "  -N  --  Build#             [eg. -N 150]               "
      echo "  -F  --  Format             [eg. -F Toshiba_4G_MLC]    "
      echo "  -L  --  Local              [eg. -L ../img/buildroot/] "
      echo ""
      echo ""
      exit 0
      ;;
    \?)
      echo "== Invalid option: -$OPTARG ==" >&2
      exit 1
      ;;
  esac
done

function require_directory {
  if [[ ! -d "${1}" ]]; then
      mkdir -p "${1}"
  fi
}

function dl_probe {

  if [ -z $CACHENUM ] && [ -z $LOCALDIR ]; then
    CACHENUM=$(curl -s $DL_URL/$BRANCH/$FLAVOR/latest)
  fi

  if [[ ! -d "$DL_DIR/$BRANCH-$FLAVOR-b${CACHENUM}" ]] && [[ -z $LOCALDIR ]]; then
    echo "== New image available =="

    rm -rf $DL_DIR/$BRANCH-$FLAVOR*
    
    mkdir -p $DL_DIR/${BRANCH}-${FLAVOR}-b${CACHENUM}
    pushd $DL_DIR/${BRANCH}-${FLAVOR}-b${CACHENUM} > /dev/null
    
    echo "== Downloading.. =="
    for FILE in ${PROBES[@]}; do
      if ! $WGET $DL_URL/$BRANCH/$FLAVOR/${CACHENUM}/$FILE; then
        echo "!! download of $BRANCH-$FLAVOR-$METHOD-b${CACHENUM} failed !!"
        exit $?
      fi
    done
    popd > /dev/null
  else
    echo "== Local/cached probe files located =="
  fi

  echo "== Staging for NAND probe =="
  if [ -z $LOCALDIR ];then
    ln -s ../../$DL_DIR/${BRANCH}-${FLAVOR}-b${CACHENUM}/ $IMAGESDIR
  else
    ln -s ../../$LOCALDIR $IMAGESDIR
  fi

  if [[ -f ${IMAGESDIR}/ubi_type ]]; then rm ${IMAGESDIR}/ubi_type; fi

  if [ -z $FORMAT ]; then
    detect_nand || exit 1
  else
    case $FORMAT in
      "Hynix_8G_MLC")
        echo hello
        export nand_erasesize=400000
        export nand_oobsize=680
        export nand_writesize=4000
      ;;
      "Toshiba_4G_MLC")
        export nand_erasesize=400000
        export nand_oobsize=500
        export nand_writesize=4000
      ;;
      "Toshiba_512M_SLC")
        echo correct
        export nand_erasesize=40000
        export nand_oobsize=100
        export nand_writesize=1000
      ;;
      *)
    	echo "== Invalid format: $FORMAT =="
    	exit 1
      ;;
    esac
    UBI_TYPE="$nand_erasesize-$nand_writesize-$nand_oobsize"
    echo $UBI_TYPE > ${IMAGESDIR}/ubi_type
  fi

  if [[ ! -f "$DL_DIR/$BRANCH-$FLAVOR-b${CACHENUM}/$UBI_PREFIX-$UBI_TYPE.$UBI_SUFFIX" ]] && [ -z $LOCALDIR ]; then
    echo "== Downloading new UBI, this will be cached for future flashes. =="
    pushd $DL_DIR/${BRANCH}-${FLAVOR}-b${CACHENUM} > /dev/null
    if ! $WGET $DL_URL/$BRANCH/$FLAVOR/${CACHENUM}/$UBI_PREFIX-$UBI_TYPE.$UBI_SUFFIX; then
      echo "!! download of $BRANCH-$FLAVOR-$METHOD-b${CACHENUM} failed !!"
      exit $?
    fi
    popd > /dev/null
  else
    if [ -z $LOCALDIR ]; then
      echo "== Cached UBI located =="
    else
      if [[ ! -f "$IMAGESDIR/$UBI_PREFIX-$UBI_TYPE.$UBI_SUFFIX" ]]; then
        echo "Could not locate UBI files"
        exit 1
      else
        echo "== Cached UBI located =="
      fi
    fi
  fi
}

echo == preparing images ==
require_directory "$IMAGESDIR"
rm -rf ${IMAGESDIR}
require_directory "$DL_DIR"

##pass
dl_probe || (
  ##fail
  echo -e "\n FLASH VERIFICATION FAILED.\n\n"
  echo -e "\tTROUBLESHOOTING:\n"
  echo -e "\tIs the FEL pin connected to GND?"
  echo -e "\tHave you tried turning it off and turning it on again?"
  echo -e "\tDid you run the setup script in CHIP-SDK?"
  echo -e "\tDownload could be corrupt, it can be re-downloaded by adding the '-f' flag."
  echo -e "\n\n"
  exit 1
)

##pass
flash_images && ready_to_roll || (
  ##fail
  echo -e "\n FLASH VERIFICATION FAILED.\n\n"
  echo -e "\tTROUBLESHOOTING:\n"
  echo -e "\tIs the FEL pin connected to GND?"
  echo -e "\tHave you tried turning it off and turning it on again?"
  echo -e "\tDid you run the setup script in CHIP-SDK?"
  echo -e "\tDownload could be corrupt, it can be re-downloaded by adding the '-f' flag."
  echo -e "\n\n"
)
