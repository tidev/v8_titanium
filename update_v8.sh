#!/bin/sh
#
# Appcelerator Titanium Mobile
# Copyright (c) 2011 by Appcelerator, Inc. All Rights Reserved.
# Licensed under the terms of the Apache Public License
# Please see the LICENSE included with this distribution for details.
#
# Reverse our patches, and update (and index) the v8 submodule to the latest from trunk

patch -p0 --reverse -i patches/ndk_v8.patch

cd v8
git pull

cd ..
git add v8
