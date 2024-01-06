MODDIR=${0%/*}
#MODDIR=/data/adb/modules/Alist_online
cd $MODDIR/
chmod +x dpkg
chmod 755 alist

backup_alist() {
	cd $MODDIR/
	mkdir -p /data/adb/Alist_online_backups/
	cp -r $MODDIR/data/* /data/adb/Alist_online_backups/
	cp $MODDIR/alist /data/adb/Alist_online_backups/
	echo "$(date +%y-%m-%d-%T)的备份文件" >> /data/adb/Alist_online_backups/backup.log
}

restore_alist() {
	cd $MODDIR/
	if [ -d /data/adb/Alist_online_backups/ ]
	then
	cp -r /data/adb/Alist_online_backups/* $MODDIR/data/
		if [ -f /data/adb/Alist_online_backups/alist ]
		then
			cp /data/adb/Alist_online_backups/alist $MODDIR/
			else
			echo "$(date +%y-%m-%d-%T)未发现备份的alist二进制文件，跳过此项" >> /data/adb/Alist_online_backups/backup.log
			continue
			fi
	chmod -R 777 $MODDIR/data/
	echo "$(date +%y-%m-%d-%T)恢复数据成功" >> /data/adb/Alist_online_backups/backup.log
	else
	echo "$(date +%y-%m-%d-%T)第一次安装，跳过恢复数据"  >> /data/adb/Alist_online_backups/backup.log
	fi
}


find_arch() {
local abi=$(file_getprop /system/build.prop ro.product.cpu.abi);
  case $abi in
    arm64*) ARCH=aarch64;;
    arm*) ARCH=arm;;
    x86_64*) ARCH=x86_64;;
    x86*) ARCH=x86;;
    mips64*) ARCH=aarch64;;
    mips*) ARCH=arm;;
    *) ui_print "Unknown architecture: $abi"; abort;;
  esac;
}
file_getprop() { grep "^$2=" "$1" | tail -n1 | cut -d= -f2-; }



start_alist() {
#开始启动
cd $MODDIR/
chmod 755 alist
echo "现在时间$(date +%y-%m-%d-%T)" >> download.log
echo "正在启动的alist版本信息:
$($MODDIR/alist version)" >> download.log
#网络连接成功才启动alist,持续检测
echo "等待网络" >> download.log
until [ "$(curl -Is qq.com)" ];do sleep 1s;done;
echo "网络连接成功" >> download.log
$MODDIR/alist server --data $MODDIR/data&
#echo "PowerManagerService.noSuspend" > /sys/power/wake_lock
}
stop_alist() {
kill $(pgrep alist)
sleep 2s
}

check_alist() {
	if [ "$(pgrep alist)" ]; then
	echo "$(date +%y-%m-%d-%T) 健康检查:alist正在运行" >> download.log
	else
	echo "$(date +%y-%m-%d-%T) 健康检查:alist未运行" >> download.log
	fi
}

update_check() {
	cd $MODDIR/
	sleep 1s
echo "$(date +%y-%m-%d-%T) 检查更新" >> download.log
find_arch
echo "$(date +%y-%m-%d-%T) 本机架构${ARCH}" >> download.log

#获取最新版本号
	url=$(timeout 50s curl -OL https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main/dists/stable/main/binary-${ARCH}/Packages && grep pool Packages |grep alist |awk '{print $2}')
	new_ver=$(grep -A 6 -i 'Package: alist' Packages|grep -iw "^version"|tr -d -c '[0-9] .')
	echo "最新版本为$new_ver" >> download.log 2>&1
	
	#如果能直接访问github，最新版本号可以这样获取curl -s "https://api.github.com/repos/alist-org/alist/releases/latest"|grep tag_name|tr -d -c '[0-9] .'
	cur_ver=$($MODDIR/alist version|grep -iw "^version"|tr -d -c '[0-9] .')
	#本模块会备份恢复上次运行alist的版本,所以模块自带的alist版本不会影响后续检测升级,使用的是上次升级后的版本
	echo "当前版本为$cur_ver" >> download.log 2>&1
  # 比较版本号
  if [[ "$cur_ver" == "$new_ver" ]]; then
      echo "版本相同，无需升级。" >> download.log
  elif [[ "$(echo -e "$cur_ver\n$new_ver" | sort -V | tail -n 1)" == "$new_ver" ]]; then
    echo "需要升级。" >> download.log
    # 更新操作开始
    mkdir -p tmp/tmp_deb/alist/
    timeout 360s curl -L https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main/${url} -o tmp/tmp_deb/alist_latest.deb
    chmod 755 dpkg
    echo "现在开始解压deb" >> download.log
    $MODDIR/dpkg -x $MODDIR/tmp/tmp_deb/alist_latest.deb $MODDIR/tmp/tmp_deb/alist/
    echo "$? 如果输出是0那么解压deb成功" >> download.log
    # 将最新版本复制到工作目录
    echo "现在开始更新" >> download.log
    if [ -f tmp/tmp_deb/alist/data/data/com.termux/files/usr/bin/alist ]
    then
    stop_alist
    echo "在更新文件前，检查alist是否还在运行" >> download.log
    check_alist
    sleep 3s
    cp tmp/tmp_deb/alist/data/data/com.termux/files/usr/bin/alist $MODDIR/
    rm -rf tmp/tmp_deb/*;
    rm -f Packages;
      start_alist
      echo "$(date +%y-%m-%d-%T) 更新成功,正在重启alist" >> download.log
    else
      echo "文件下载失败，请重启设备再试" >> download.log
    fi
    # 更新操作结束
  else
    echo "$(date +%y-%m-%d-%T) 无需更新" >> download.log
  fi
}

#启动alist
#stop_alist
#修复模块安装过程中data目录数据被覆盖问题
#这里是将上次的备份数据恢复到data目录，最快的一次备份数据也要启动5分钟后才有
restore_alist
sleep 1s
start_alist
check_alist
update_check
check_alist
#5分钟后备份一次
sleep 5m
backup_alist
#60分钟后备份一次的数据
sleep 60m
backup_alist
#每天备份一次，同时进行检测更新
while true;
do
	sleep 1d
	backup_alist
	update_check
	sleep 1s
	check_alist
	done
