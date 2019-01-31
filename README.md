# CHIP-tools
A collection of scripts for working with CHIP - now working.

## Requirements
1) **sunxi-tools** from your package manager or from the [Sunxi repository](https://github.com/linux-sunxi/sunxi-tools.git)
2) **uboot-tools** from your package manager
2) **mtd-utils-mlc** from our repository (http://chip.jfpossibilities.com/gits/CHIP-mtd-utils.git) [for creating images]

## Included Tools
### chip-update-firmware
This tool is used to download and flash the latest firmware release for CHIP. The tool also now only supports fastboot flashing.

### chip-create-nand-images
This tool is used to generate local firmware images for CHIP and CHIP Pro.

This version of CHIP-tools will download files from [jfpossibilities' mirror](http://chip.jfpossibilities.com), because the official repository is down.
More info at http://www.chip-community.org/index.php/Archives
