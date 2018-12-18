# CHIP-tools
A collection of scripts for working with CHIP

## Requirements
1) **sunxi-tools** from your package manager or from the [Sunxi repository](https://github.com/linux-sunxi/sunxi-tools.git)
2) **uboot-tools** from your package manager
2) **mtd-utils-mlc** from our repository (https://github.com/nextthingco/chip-mtd-utils) [for creating images]

## Included Tools
### chip-update-firmware
This tool is used to download and flash the latest firmware release for CHIP. The tool also now only supports fastboot flashing.

### chip-create-nand-images
This tool is used to generate local firmware images for CHIP and CHIP Pro.
