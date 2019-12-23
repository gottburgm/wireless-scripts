#!/bin/bash

apt-get install -y python-m2crypto

rm -rf /tmp/crda &>/dev/null
rm -rf /tmp/wireless-regdb &>/dev/null

git clone git://git.kernel.org/pub/scm/linux/kernel/git/sforshee/crda.git /tmp/crda
git clone git://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git /tmp/wireless-regdb

sed 's#/usr/bin/env python#/usr/bin/python2#g' -i /tmp/wireless-regdb/db2bin.py
sed 's#/usr/bin/env python#/usr/bin/python2#g' -i /tmp/crda/utils/key2pub.py

cd /tmp/wireless-regdb/
make
make install
cp -v /tmp/wireless-regdb/*.key.pub.pem /tmp/crda/pubkeys/

cd /tmp/crda
make
make install
