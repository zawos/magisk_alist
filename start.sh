#!/system/bin/sh
MODDIR=${0%/*}
kill $(pgrep alist) &&
alist admin &&
alist server --data data&