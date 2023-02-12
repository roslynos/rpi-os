#!/bin/bash

# Abort script if any command returns error
set -e

BUILD_DIR="build"
TEMPLATECONF=${TEMPLATECONF:-${PWD}/meta-roslynos/conf/templates/default}

declare -a machines=("raspberrypi0-2w-64" "raspberrypi3-64" "raspberrypi4-64")
declare -a recipes=("roslynos-image" "package-index")

# declare -a machines=("raspberrypi4-64")
# declare -a recipes=("roslynos-image")

install() {
    echo -e "Installing dependencies\n"
    sudo apt-get update
    sudo apt-get install -y language-pack-en
    sudo apt-get install -y gawk wget git diffstat unzip texinfo gcc build-essential \
        chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils \
        iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev \
        xterm python3-subunit mesa-common-dev zstd liblz4-tool file
}

init() {
  conf_file="default.conf"
  
  _parse_conf
  _clone

  _source
  bitbake-layers add-layer ../meta-roslynos/
  bitbake-layers add-layer ../poky/meta-raspberrypi/
  bitbake-layers add-layer ../poky/meta-openembedded/meta-oe/
  bitbake-layers add-layer ../poky/meta-openembedded/meta-python/
  bitbake-layers add-layer ../poky/meta-openembedded/meta-multimedia/
  bitbake-layers add-layer ../poky/meta-openembedded/meta-networking/
  
  bitbake bmap-tools-native -caddto_recipe_sysroot
}

bake() {
  _source

  for machine in ${machines[*]}; do
    for recipe in ${recipes[*]}; do
      MACHINE="$machine" bitbake "$recipe" $1
    done
  done
}

clean() {
  _source

  for machine in ${machines[*]}; do
    for recipe in ${recipes[*]}; do
      MACHINE="$machine" bitbake "$recipe" -c clean
    done
  done
}

flash() {
  _source

  if [ "$2" = "/dev/sda" ] ; then
    echo "Invalid device specified $2"
    exit 1
  fi
  
  while [[ $# -gt 1 ]]; do    
    # ls "$2"? | xargs -n1 udisksctl unmount -b
    # sudo umount `lsblk --list | grep mmcblk0 | grep part | gawk '{ print $7 }' | tr '\n' ' '`
    sudo chmod 666 "$2" 
    oe-run-native \
      bmap-tools-native bmaptool copy \
      $PWD/tmp/deploy/images/"$1"/roslynos-image-"$1".wic \
      "$2"
    
    # udisksctl power-off -b "$2"
    exit 0
  done

  echo "Invalid options specified"
  exit 1
}

update() {
  git fetch --all
}

packagelist() {
  _source

  bitbake -g "$1"
  cat pn-buildlist | grep -v native | sort
}

_source() {
  source ./poky/oe-init-build-env $BUILD_DIR
}

_parse_conf() {
  if [ ! -f $conf_file ]; then
    echo "$conf_file not found!"
    exit 1
  fi

  echo -e "Parsing $conf_file..."
  repo_urls=( $(grep ^repository $conf_file | cut -d ',' -f2) )
  repo_dirs=( $(grep ^repository $conf_file | cut -d ',' -f3) )
  repo_branch=( $(grep ^repository $conf_file | cut -d ',' -f4) )
  echo "done\n"
}

_clone() {
  for (( i=0; i<${#repo_urls[@]}; i++ ));
  do
    if [ -d ${repo_dirs[$i]} ]; then
        if [ "$force" = true ] ; then
            echo "Removing ${repo_dirs[$i]}"
            rm -fr ${repo_dirs[$i]}
        else
            echo "Warning: Directory ${repo_dirs[$i]} exists. Skipping..."
            continue
        fi
    fi
      
      git clone -b ${repo_branch[$i]} ${repo_urls[$i]} ${repo_dirs[$i]}
      echo ""
  done
}

if [[ $# -eq 0 ]] ; then
  bake
fi

case $1 in
  install)
    shift
    install "$@"
    ;;
  init)
    shift
    init "$@"
    ;;
  bake)
    shift
    bake "$@"
    ;;
  clean)
    shift
    clean "$@"
    ;;
  flash)
    shift
    flash "$@"
    ;;
  update)
    shift
    update "$@"
    ;;
  packagelist)
    shift
    packagelist "$@"
    ;;
esac