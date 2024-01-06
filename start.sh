#!/system/bin/sh
MODDIR=${0%/*}
kill $(pgrep alist) &&
$MODDIR/alist admin &&
$MODDIR/alist server --data $MODDIR/data&