#!/bin/bash
# exit 29 tar file error
# exit 30 yum error
# exit 31 depending install error
# exit 32 confingure error
# exit 33 make error
# exit 34 make install error


# static variable
NULL=/dev/null
PHP_INTAR="php-5.4.24.tar.gz"
DEP_MHASH="mhash-0.9.9.9.tar.gz"
DEP_LIB="libmcrypt-2.5.8.tar.gz"

test_yum () {
	yum clean all &> $NULL
	repolist=$(yum repolist | awk  '/repolist:.*/{print $2}' | sed 's/,//')
	if [ $repolist -gt 0 ];then
		return 0
	fi
	return 1
}

print_info () {
	if [ -n "$1" ] && [ -n "$2" ] ;then
		case "$2" in 
		OK)
			echo -e "$1 \t\t\t \e[32;1m[OK]\e[0m"
			;;
		Fail)
			echo -e "$1 \t\t\t \e[31;1m[Fail]\e[0m"
			;;
		*)
			echo "Usage info {OK|Fail}"
		esac
	fi
}

rotate_line(){
	INTERVAL=0.1
	TCOUNT="0"
	while :
	do
		TCOUNT=`expr $TCOUNT + 1`
		case $TCOUNT in
		"1")
			echo -e '-'"\b\c"
			sleep $INTERVAL
			;;
		"2")
			echo -e '\\'"\b\c"
			sleep $INTERVAL
			;;
		"3")
			echo -e "|\b\c"
			sleep $INTERVAL
			;;
		"4")
			echo -e "/\b\c"
			sleep $INTERVAL
			;;
		*)
			TCOUNT="0";;
		esac
	done
}

## $1 应该传入前一个命令的$?.$2为之前操作的名称,$3为出现错误时推出的参数
result_info () {
	#if [ $1 != [0-9] ] && [ "$2" -n ] && [ "$3" -n ] ;then
	
		if [ "$1" -eq 0 ];then
			print_info "$2" "OK"
		elif [ "$1" -ne 0 ];then
			print_info "$2" "Fail"
			exit "$3"
		else
			exit 35
		fi
	#fi
}

test_yum
if [ $? -ne 0 ];then
  print_info "yum error." "Fail"
  exit 30
fi


rotate_line &
disown $!
yum -y install libxml2-devel > $NULL
yum -y install gcc* > $NULL
result=$?
kill -9 $!
[ $result -eq 0 ] ||  exit 31

[ -f $DEP_MHASH ] || exit 31
mhash_dir=$(tar -tf $DEP_MHASH | head -1)
tar -xf $DEP_MHASH >$NULL
result_info $? "de tar install file." "29"
cd $mhash_dir

rotate_line &
disown $!
[ -f configure ] && ./configure || exit 31
make  > $NULL
result_info $? "mhash make." "31"
make install > $NULL
result_info $? "mhash make install." "31"
kill -9 $!

cd ..

[ -f $DEP_LIB ] || exit 31
lib_dir=$(tar -tf $DEP_LIB | head -1)
tar -xf $DEP_LIB >$NULL
result_info $? "de tar install file." "29"
cd $lib_dir

rotate_line &
disown $!
[ -f configure ] && ./configure || exit 31
make  > $NULL
result_info $? "libc make." "31"
make install  > $NULL
result_info $? "libc make install." "31"
kill -9 $!

grep "/usr/local/lib/" /etc/ld.so.conf &> $NULL
if [ $? -ne 0 ];then
	sed -i '$a /usr/local/lib/' /etc/ld.so.conf	
	idconfig
fi

cd ..

if [ ! -f $PHP_INTAR ];then
	print_info "php_intar no such file." "Fail"
	exit 29
fi

php_dir=$(tar -tf $PHP_INTAR | head -1)
tar -xf $PHP_INTAR
#echo "php_dir=$php_dir"
cd $php_dir
if [ ! -f configure ];then
	print_info "configure no such file." "Fail"
	exit 32
fi

rotate_line &
disown $!

# ./configure --prefix=/usr/local/php5 --with-mysql=/usr/local/mysql --enable-fpm  --enable-mbstring --with-mcrypt --with-mhash --with-config-file-path=/usr/local/php5/etc --with-mysqli=/usr/local/mysql/bin/mysql_config > $NULL

#./configure --prefix=/usr/local/php5 \ 	#安装路仅
#--with-mysql=/usr/local/mysql\ 			#指定MySQL位置
#--enable-fpm \  						#安装PHP-fpm服务，必须要设置，开发人员可不要，运维人员必须要设置
#--enable-mbstring \						#多字节字符[汉字支持]
#--with-mcrypt  --with-mhash \ 			#启用加密和hash功能
#--with-config-file-path=/usr/local/php5/etc\   #制定PHP的配置文件存放路径
#--with-mysqli=/usr/local/mysql/bin/mysql_config
#result_info $? "configure" "32"

./configure --prefix=/usr/local/php-5.5.7 \
--with-config-file-path=/usr/local/php-5.5.7/etc \
--with-bz2 --with-curl \
--enable-ftp --enable-sockets --disable-ipv6 --with-gd \
--with-jpeg-dir=/usr/local --with-png-dir=/usr/local \
--with-freetype-dir=/usr/local --enable-gd-native-ttf \
--with-iconv-dir=/usr/local --enable-mbstring --enable-calendar \
--with-gettext --with-libxml-dir=/usr/local --with-zlib \
--with-pdo-mysql=mysqlnd --with-mysqli=mysqlnd --with-mysql=mysqlnd \
--enable-dom --enable-xml --enable-fpm --with-libdir=lib64 --enable-bcmath

make > $NULL
result_info $? "make" "33"

make install > $NULL
result_info $? "make install" "34"

kill -9 $!

/bin/cp -f  php.ini-production /usr/local/php5/etc/php.ini
/bin/cp -f /usr/local/php5/etc/php-fpm.conf.default /usr/local/php5/etc/php-fpm.conf

