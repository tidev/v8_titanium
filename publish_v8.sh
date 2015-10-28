#!/bin/sh
#
# Appcelerator Titanium Mobile
# Copyright (c) 2011 by Appcelerator, Inc. All Rights Reserved.
# Licensed under the terms of the Apache Public License
# Please see the LICENSE included with this distribution for details.
#
# Uploads a libv8 tarball to S3.
# Requires s3cmd, which must be setup using s3cmd --configure
# http://s3tools.org/s3cmd
# http://tcpdiag.dl.sourceforge.net/project/s3tools/s3cmd/1.6.0/s3cmd-1.6.0.tar.gz
# Requires python2, ugh

LIBV8=$1

if [ "$LIBV8" = "" ]; then
	echo "Usage: $0 build/libv8-<version>.tar.bz2"
	exit 1
fi

echo "Uploading $LIBV8..."

BASENAME=$(basename "$LIBV8")
s3cmd put --acl-public --guess-mime-type $LIBV8 s3://timobile.appcelerator.com/libv8/$BASENAME
