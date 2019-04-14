# CHIP-tools
A collection of scripts for working with CHIP - now working.
***
## Requirements
1) **sunxi-tools** from your package manager or from the [Sunxi repository](https://github.com/linux-sunxi/sunxi-tools.git)
2) **uboot-tools** from your package manager
2) **mtd-utils-mlc** from [this repository](http://chip.jfpossibilities.com/gits/CHIP-mtd-utils.git) [for creating images]
***
## Included Tools:
### chip-update-firmware
This tool is used to download and flash the latest firmware release for CHIP. The tool also now only supports fastboot flashing.
` sudo ./chip-update-firmware <option>`
- Avaliable options:
1. Server (`-s`) Headless (no user interface).
2. GUI (`-g`) Debian + XFCE
3. PocketCHIP (`-p`) Debian + Pockethome interface
4. Buildroot (`-b`) Flashes tiny, but powerful image
5. Redownload (`-f`) Remove the local files and redownload them
6. No limit (`-n`) Enable greater power draw
7. Reset (`-r`) Resets the device after flash
8. Branch (`-B`) Set the branch you want to flash e.g. `-B testing`
9. Build (`-N`) Set the build you want to flash e.g. `-N 150`
10. Format (`-F`) Set the NAND model e.g. `-F Toshiba_4G_MLC`
11. Local (`-L`) Flash a local image e.g. `-L ../img/buildroot/`
### chip-create-nand-images
This tool is used to generate local firmware images for CHIP and CHIP Pro.

This version of CHIP-tools will download files from [jfpossibilities' mirror](http://chip.jfpossibilities.com), because the official repository is down.
More info at http://www.chip-community.org/index.php/Archives
