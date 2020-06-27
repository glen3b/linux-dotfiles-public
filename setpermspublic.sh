#!/bin/sh
chmod -R u+rw,go+r-w "$1"
find "$1" -perm -u=x -execdir chmod a+x {} +
