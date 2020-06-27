#!/bin/bash
set -e
cd "${0%/*}"
declare -A comment_prefixes=( ["text/x-shellscript"]="# " ["text/x-perl"]="# " ["text/x-python"]="# ")
# INSTALL_DATE_SIGNATURE="Installed from dotfile repository at $(pwd) (commit $(git rev-parse --short HEAD)) on $(date)"
