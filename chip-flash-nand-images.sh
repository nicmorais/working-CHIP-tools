#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/common.sh

IMAGESDIR="$1"
ERASEMODE="$2"
PLATFORM="$3"

detect_nand
flash_images
