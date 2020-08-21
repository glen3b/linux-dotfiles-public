#!/bin/bash
set -e
cd "${0%/*}"
declare -A comment_prefixes=( ["text/x-shellscript"]="# " ["text/x-perl"]="# " ["text/x-python"]="# ")
