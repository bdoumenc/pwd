#!/usr/bin/env bash

dir=$(dirname $(readlink -f $0))
cd $dir

make -j$((2 * $(cat /proc/cpuinfo | grep ^processor | wc -l)))

release_dir=$dir/target/release
test -d $release_dir && rm -rf $release_dir

BIN=$release_dir/bin
EXE=$release_dir/share/pwdmgr
DOC=$release_dir/share/doc/pwdmgr
CONF=$release_dir/etc

for dir in $BIN $EXE $DOC $CONF
do
    mkdir -p $dir
done

umask 222

for src in bin/pwdmgr_*
do
    tgt=$BIN/$(basename $src)
    sed 's|^dist=.*$|exe=$(dirname $(dirname $(readlink -f $0)))/share/pwdmgr|;s| \$prop$||g' < $src > $tgt
    chmod a+x $tgt
done

cp exe/* $EXE/
cp COPYING README.md $DOC/
cp conf/pwdmgr-local.properties $DOC/sample-local-pwdmgr.rc
cp conf/pwdmgr-remote.properties $DOC/sample-remote-pwdmgr.rc
cp conf/pwdmgr-remote.properties $CONF/pwdmgr.rc

cat >$release_dir/install.sh <<EOF
#!/bin/sh

if [ \$(id -u) -eq 0 ]; then
    echo Installing as root
    PREFIX=\${1:-\${PREFIX:-/usr/local}}
else
    echo Installing as \$USER
    PREFIX=\${1:-\${PREFIX:-\$HOME/.local}}
    mkdir -p \$PREFIX
fi

for src in bin/*
do
    tgt=\$PREFIX/bin/\$(basename \$src)
    sed 's|^exe=.*$|exe='"\$PREFIX"'/share/pwdmgr|' < \$src > \$tgt
    chmod a+x \$tgt
done

for tgt in \$(find share -type d -name pwdmgr) etc/*
do
    if [ -d \$tgt ]; then
        test -d \$PREFIX/\$tgt && rm -rf \$PREFIX/\$tgt
        cp -a \$tgt \$PREFIX/\$tgt
    else
        cp -f \$tgt \$PREFIX/\$tgt
    fi
done

if [ \$(id -u) -ne 0 ]; then
    dir=\$HOME/.pwdmgr
    test -d \$dir || mkdir \$dir
    test -e \$dir/config.rc || cp \$PREFIX/etc/pwdmgr.rc \$dir/config.rc # should we ln -s instead?
fi
EOF
chmod a+x $release_dir/install.sh
