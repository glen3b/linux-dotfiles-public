#!/bin/bash
cd "${0%/*}"
. install-common.sh
set -e
echo "$2"

# make a singular backup
# this saves us if the script bugs - but for one run only
pushd "${2%/*}" >/dev/null 2>&1
FILE_BASENAME=$(basename -- "$2")
if [ -f "$FILE_BASENAME" ]; then
    mv "$FILE_BASENAME" ".$FILE_BASENAME.bak~"
    # this is likely to be in the path - so remove executability from the backup
    chmod a-x ".$FILE_BASENAME.bak~"
fi
popd >/dev/null 2>&1

# actual install
cp -P --preserve=mode,timestamps,links,xattr "$1" "$2"
# only chown regular files
[ -f "$2" ] && chown "$(id -u):$(id -g)" "$2"

FILETYPE=$(file -bi "$2" | cut -d';' -f1)

( [ ${comment_prefixes["$FILETYPE"]+abc} ] && printf "\n%s%s\n" "${comment_prefixes[$FILETYPE]}" "$INSTALL_DATE_SIGNATURE" >> "$2" ) || true
