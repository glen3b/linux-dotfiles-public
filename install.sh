#!/bin/bash
#cd "${0%/*}"
#echo "$(dirname "${BASH_SOURCE[0]}")"
set -u
set -e
cd "$( dirname "${BASH_SOURCE[0]}" )"
. install-common.sh
echo Dotfile installer starting
export INSTALL_DATE_SIGNATURE="Installed from dotfile repository at $(pwd) (commit $(git rev-parse --short HEAD)) on $(date)"
echo Installing files in homedirectory...
# hacky approach
# start with 'home' (which auto-prepends dots)
find home -type d -printf 'mkdir -p ~/.%P\n' | bash
find home \( -type f -o -type l \) -printf './install-file.sh %p ~/.%P\n' | bash
find home.dotless -type d -printf 'mkdir -p ~/%P\n' | bash
find home.dotless \( -type f -o -type l \) -printf './install-file.sh %p ~/%P\n' | bash
if [[ -d private/home ]] && [[ -d private/home.dotless ]]; then
    echo [Private] Installing files in homedirectory...
    find private/home -type d -printf 'mkdir -p ~/.%P\n' | bash
    find private/home \( -type f -o -type l \) -printf './install-file.sh %p ~/.%P\n' | bash
    find private/home.dotless -type d -printf 'mkdir -p ~/%P\n' | bash
    find private/home.dotless \( -type f -o -type l \) -printf './install-file.sh %p ~/%P\n' | bash
fi
echo Installing files in usr local...
find usrlocal -type d -printf 'mkdir -p /usr/local/%P\n' | sudo env "INSTALL_DATE_SIGNATURE=$INSTALL_DATE_SIGNATURE" bash
find usrlocal \( -type f -o -type l \) -printf './install-file.sh %p /usr/local/%P\n' | sudo env "INSTALL_DATE_SIGNATURE=$INSTALL_DATE_SIGNATURE" bash
