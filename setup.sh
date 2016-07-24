#!/bin/bash
# FULL fast install/upgrade script
# See help message via `--help'
# $Id$

# self check
if ! test -d ./packages ; then
  echo "ERROR: you should run the script under its directory"
  echo "错误：您只能在脚本所在目录运行它"
  exit -1
fi

# get default prefix
if test -f $HOME/.xs_installed ; then
  def_prefix=`cat $HOME/.xs_installed`
elif test "$HOME" = "/" || test "$HOME" = "/root" ; then
  def_prefix=/usr/local/xunsearch
else
  def_prefix=$HOME/xunsearch
fi

# clean
do_clean()
{
  echo -n "Cleaning ... "
  rm -rf setup.log
  rm -rf libevent* libuuid* scws* xapian* xunsearch*
  echo "done"
}

# show usage
show_usage()
{
  echo "Usage: $0 [options]"
  echo "       --prefix=DIR             Specify install directory, default: $def_prefix"
  echo "       --no-clean               Keep extracted package files after installation completed"
  echo "       --force                  Force to recompile all packages"
  echo "       --enable-debug           Trun on debug symbol and verbose log info"
  echo "       --enable-memory-cache    Enable memory cache for xs-searchd"
  echo "                                (Notice: This feature may cause unstable on some OS)"
  echo "       --jobs=N                 Specify the number of make jobs to run simultaneously"
  echo "       --help                   Show these messages"
}

# parse arguments
set_prefix=
set_force="no"
set_no_clean="no"
mk_add_option=
xs_add_option=

i=0
while [ $i -lt $# ] ; do
  i=`expr $i + 1`
  eval arg=\$$i
  opt=`echo $arg | cut -d= -f1`
  val=`echo $arg | cut -d= -f2`
  case $opt in
	"--prefix")
	  set_prefix="$val"
	;;
	"--no-clean")
	  set_no_clean=yes
	;;
	# just for back compatibility
	"--clean")
	  do_clean
	  exit
	;;
	"--force")
	  if test "$val" != "no" ; then
        set_force=yes
      fi
	;;
	"--enable-debug"|"--enable-memory-cache")
	  xs_add_option="$xs_add_option $arg"
	;;
	"--jobs")
	  mk_add_option="$mk_add_option -j$val"
	;;
	"--help")
      show_usage
      exit
	;;
	*)
	  echo "ERROR: unknown option '$arg'" >&2
	  echo "" >&2
	  show_usage
	  exit -1
	;;
  esac
done

# welcome msg
echo
echo "+==========================================+"
echo "| Welcome to setup xunsearch(full)         |"
echo "| 欢迎使用 xunsearch (完整版) 安装程序     |"
echo "+------------------------------------------+"
echo "| Follow the on-screen instructions please |"
echo "| 请按照屏幕上的提示操作以完成安装         |"
echo "+==========================================+"
echo

# ask prefix
if test "$set_prefix" = ""; then
echo "Please specify the installation directory"
echo "请指定安装目录 (默认为中括号内的值)"
echo -n "[$def_prefix]:"
while test -z ""; do
  read -e set_prefix
  if test $? -ne 0 ; then
    echo -n "[$def_prefix]:"
    read set_prefix
  fi
  if test -z "$set_prefix" ; then
    set_prefix=$def_prefix
  fi
  echo
  echo "Confirm the installation directory"
  echo -n "请确认安装目录：$set_prefix [Y/n]"
  read res_prefix
  if test -z "$res_prefix" || test "$res_prefix" = "y" || test "$res_prefix" = "Y" ; then
    break
  fi
  echo
  echo "Please re-input the installation directory"
  echo "请重新输入安装目录"
  echo -n "[$set_prefix]:"
done
echo
else
echo "Specified installation directory: $set_prefix"
fi

# record it
prefix=$set_prefix
echo $prefix > $HOME/.xs_installed

# compile flags
export CFLAGS=-O2
export CXXFLAGS=-O2
echo -n > setup.log

# error function
setup_abort()
{
  echo "-----"
  tail -10 ../setup.log
  echo "-----"
  echo "ERROR: failed to $1, see 'setup.log' for more detail"
  exit 3
}

# check & install scws
old_version=
echo -n "Checking scws ... "
if test -f $prefix/include/scws/version.h ; then
  old_version=`cat $prefix/include/scws/version.h | grep VERSION | cut -d\" -f2`
  echo $old_version
else
  echo "no"
fi
do_install=$set_force
new_file=`ls -d ./packages/scws-* | grep -v dict`
new_version=`echo $new_file | sed 's#^.*scws-\(.*\)#\1#'`
if test -z "$old_version" ; then
  if test -z "$new_version" ; then
    echo "ERROR: Missing scws package (缺少 scws 安装包)"
    exit 2
  fi
  echo "Installing scws ($new_version) ... "
  do_install=yes
elif ! test -z "$new_version" && test "$new_version" != "$old_version" ; then
  echo "Upgrading scws ($old_version -> $new_version)"
  do_install=yes
fi

if test "$do_install" = "yes" ; then
  cp -r packages/scws-$new_version scws-$new_version
  cd scws-$new_version
  echo "Configuring scws ..."
  chmod +x configure
  ./configure --prefix=$prefix >> ../setup.log 2>&1
  if test $? -ne 0 ; then
    setup_abort "configure scws"
  fi
  echo "Compiling & installing scws ..."
  make clean >> ../setup.log 2>&1
  make $mk_add_option install >> ../setup.log 2>&1
  if test $? -ne 0 ; then
    setup_abort "compile scws"
  fi
  cd ..
fi

# check & install scws dict
do_install=$set_force
new_dict=./packages/dict.utf8.xdb
old_dict=$prefix/etc/dict.utf8.xdb
echo -n "Checking scws dict ... "
if test -f $old_dict ; then
  if test $new_dict -nt $old_dict ; then
    echo "expired"
    echo "Updating new scws dict file ... "
    do_install=yes
  else
    echo "ok"
  fi
else
  echo "no"
  echo "Extracting scws dict file ... "
  do_install=yes
fi
if test "$do_install" = "yes" ; then
  cp $new_dict $prefix/etc
  touch $old_dict
fi

# check & install libuuid
uuid_place=
dir_list="/usr /usr/local $prefix"
echo -n "Checking libuuid ... "
for tmp in $dir_list ; do
  if test -f $tmp/include/uuid/uuid.h ; then
    uuid_place=$tmp
    break
  fi
done
if test -z "$uuid_place" ; then
  uuid_place=$prefix
  echo "no, try to install it"
  cp -r packages/libuuid-1.0.0 libuuid-1.0.0
  cd libuuid-1.0.0
  echo "Configuring libuuid ..."
  chmod +x configure
  ./configure --prefix=$prefix >> ../setup.log 2>&1
  if test $? -ne 0 ; then
    setup_abort "configure libuuid"
  fi
  echo "Compiling & installing libuuid ..."
  make clean >> ../setup.log 2>&1
  make $mk_add_option install >> ../setup.log 2>&1
  if test $? -ne 0 ; then
    setup_abort "compile libuuid"
  fi
  cd ..
else
  echo "yes: $uuid_place"
fi
xapian_env=
if test "$uuid_place" = "$prefix" ; then
  xapian_env="CXXFLAGS=-I$prefix/include LDFLAGS=-L$prefix/lib"
fi

# check & install xapian-scws
old_version=
echo -n "Checking xapian-core-scws ... "
if test -f $prefix/include/xapian/version.h ; then
  old_version=`cat $prefix/include/xapian/version.h | grep XAPIAN_VERSION | cut -d\" -f2`
  echo $old_version
else
  echo "no"
fi
do_install=$set_force
new_file=`ls -d ./packages/xapian-core-scws-*`
new_version=`echo $new_file | sed 's#^.*xapian-core-scws-\(.*\)#\1#'`
if test -z "$old_version" ; then
  if test -z "$new_version" ; then
    echo "ERROR: Missing xapian-core-scws package (缺少 xapian-core-scws 安装包)"
    exit 2
  fi
  echo "Installing xapian-core-scws ($new_version) ... "
  do_install=yes
elif ! test -z "$new_version" && test "$new_version" != "$old_version" ; then
  echo "Upgrading xapian ($old_version -> $new_version)"
  do_install=yes
fi

if test "$do_install" = "yes" ; then
  cp -r packages/xapian-core-scws-$new_version xapian-core-scws-$new_version
  cd xapian-core-scws-$new_version
  echo "Configuring xapian-core-scws ..."
  chmod +x configure
  ./configure --prefix=$prefix --with-scws=$prefix $xapian_env >> ../setup.log 2>&1
  if test $? -ne 0 ; then
    setup_abort "configure xapian-core-scws"
  fi
  echo "Compiling & installing xapian-core-scws ..."
  make clean >> ../setup.log 2>&1
  make $mk_add_option install >> ../setup.log 2>&1
  if test $? -ne 0 ; then
    setup_abort "compile xapian-core-scws"
  fi
  cd ..
fi

# check & install libevent
old_version=
echo -n "Checking libevent ... "
if test -f $prefix/include/event2/event-config.h ; then
  old_version=`cat $prefix/include/event2/event-config.h | grep EVENT_VERSION | cut -d\" -f2`
  echo $old_version
else
  echo "no"
fi
do_install=$set_force
new_file=`ls -d ./packages/libevent-*`
new_version=`echo $new_file | sed 's#^.*libevent-\(.*\)#\1#'`
if test -z "$old_version" ; then
  if test -z "$new_version" ; then
    echo "ERROR: Missing libevent package (缺少 libevent 安装包)"
    exit 2
  fi
  echo "Installing libevent ($new_version) ... "
  do_install=yes
elif ! test -z "$new_version" && test "$new_version" != "$old_version" ; then
  echo "Upgrading libevent ($old_version -> $new_version)"
  do_install=yes
fi

if test "$do_install" = "yes" ; then
  cp -r packages/libevent-$new_version libevent-$new_version
  cd libevent-$new_version
  echo "Configuring libevent ..."
  chmod +x configure
  ./configure --prefix=$prefix >> ../setup.log 2>&1
  if test $? -ne 0 ; then
    setup_abort "configure libevent"
  fi
  echo "Compiling & installing libevent ..."
  make clean >> ../setup.log 2>&1
  make $mk_add_option install >> ../setup.log 2>&1
  if test $? -ne 0 ; then
    setup_abort "compile libevent"
  fi
  cd ..
fi

# install/upgrade xunsearch
new_file=`ls -d ./packages/xunsearch-*`
new_version=`echo $new_file | sed 's#^.*xunsearch-\(.*\)#\1#'`
if test -z "$new_version" ; then
  echo "ERROR: Missing xunsearch package (缺少 xunsearch 安装包)"
  exit 2
fi
cp -r packages/xunsearch-$new_version xunsearch-$new_version
cd xunsearch-$new_version
echo "Configuring xunsearch ..."
cp -r KeyExtract/Data $prefix
if [ $(getconf WORD_BIT) = '32' ] && [ $(getconf LONG_BIT) = '64' ] ; then
    cp KeyExtract/linux64/libKeyExtract.so /usr/local/lib
else
    cp KeyExtract/linux32/libKeyExtract.so /usr/local/lib
fi
chmod +x configure
./configure --prefix=$prefix --with-scws=$prefix $xs_add_option \
--with-libevent=$prefix --with-xapian=$prefix >> ../setup.log 2>&1
if test $? -ne 0 ; then
  setup_abort "configure xunsearch"
fi
echo "Compiling & installing xunsearch ..."
make clean >> ../setup.log 2>&1
make $mk_add_option install >> ../setup.log 2>&1
if test $? -ne 0 ; then
  setup_abort "compile xunsearch"
fi
cd ..

# clean
if test "$set_no_clean" = "no" ; then
  do_clean
fi

# all done
echo
echo "+=================================================+"
echo "| Installation completed successfully, Thanks you |"
echo "| 安装成功，感谢选择和使用 xunsearch              |"
echo "+-------------------------------------------------+"
echo "| 说明和注意事项：                                |"
echo "| 1. 开启/重新开启 xunsearch 服务程序，命令如下： |"
echo "|    $prefix/bin/xs-ctl.sh restart"
echo "|    强烈建议将此命令写入服务器开机脚本中         |"
echo "|                                                 |"
echo "| 2. 所有的索引数据将被保存在下面这个目录中：     |"
echo "|    $prefix/data"
echo "|    如需要转移到其它目录，请使用软链接。         |"
echo "|                                                 |"
echo "| 3. 您现在就可以在我们提供的开发包(SDK)基础上    |"
echo "|    开发您自己的搜索了。                         |"
echo "|    目前只支持 PHP 语言，参见下面文档：          |"
echo "|    $prefix/sdk/php/README"
echo "+=================================================+"
echo
exit
