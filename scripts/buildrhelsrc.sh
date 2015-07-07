#!/bin/sh
# Copyright(c) 2015 Red Hat
# and individual contributors as indicated by the @authors tag.
# See the copyright.txt in the distribution for a
# full listing of individual contributors.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library in the file COPYING.LIB;
# if not, write to the Free Software Foundation, Inc.,
# 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
#
# @author Jean-Frederic Clere
#

# parameters
# $1: package name
# $2: branch
#
# package name:
# Something like tomcat7 (http://pkgs.devel.redhat.com/cgit/rpms/tomcat7/)
#
# branch:
# Something like jws-3.0-rhel-7 (http://pkgs.devel.redhat.com/cgit/rpms/tomcat7/?h=jws-3.0-rhel-7)

package=$1
branch=$2

if [ -d $package ]; then
  echo "$package already here... Please remove it"
  exit
fi

rhpkg clone -b $branch $package
if [ $? -ne 0 ]; then
  echo "rhpkg clone -b $branch $package Failed"
  exit
fi

(cd $package
 rhpkg sources
 if [ $? -ne 0 ]; then
   echo "rhpkg clone -b $branch $package Failed"
   exit
 fi
)
sourceslist=`cat ${package}/sources | awk '{ print $2 }'`
for fname in ${sourceslist}
do
  echo "extracting file: $fname"
  # expand the file.
  case $fname in
    *.tar.bz2)
      bzip2 -dc ${package}/${fname} | tar -xf -
      if [ $? -ne 0 ];then
        echo "extract $fname failed"
        exit 1
      fi
      dirsources=`bzip2  -dc ${package}/${fname} | tar -tf - | head -1 | awk '{ print $1 }'`
      ;;
    *.tar.gz)
      gunzip -c ${package}/${fname} | tar -xf -
      if [ $? -ne 0 ];then
        echo "extract $fname failed"
        exit 1
      fi
      dirsources=`gunzip -c ${package}/${fname} | tar -tf - | head -1 | awk '{ print $1 }'`
      ;;
    *)
      echo "$fname can't expanded"
      exit 1
      ;;
  esac
done
cp ${package}/* $dirsources

echo "sources in ${dirsources}"

#
# Read the patches list and apply them
patch=patch
WHERE=$$.tempdir
packagedir=`(cd $package; pwd)`
mkdir -p ${WHERE}
grep "^%patch" ${package}/${package}.spec | sed 's:%:@:' | sed 's: :@ :' | awk ' { print $1 " " $2 } ' > ${WHERE}/patch.cmd
grep "^Patch" ${package}/${package}.spec | sed 's:^Patch:@patch:' | sed 's/:/@/' |  awk ' { print "s:" $1 ": @PATCH@ -i @DIR@" $2 ":" } ' > ${WHERE}/patch.files
sed -f ${WHERE}/patch.files ${WHERE}/patch.cmd | sed "s:@DIR@:${packagedir}/:" | sed "s:@PATCH@:${patch}:" > ${WHERE}/patch.sh

echo "Applying the rhel patches to ${dirsources}"
chmod a+x ${WHERE}/patch.sh
WHERE=`(cd $WHERE; pwd)`
(cd ${dirsources}
 ${WHERE}/patch.sh
)
