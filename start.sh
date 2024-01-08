#!/system/bin/sh
kill $(pgrep alist) &&
./alist admin &&
./alist server --data data&