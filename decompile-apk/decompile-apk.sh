#!/bin/bash

FRAMEWORK=framework-res.apk
APK=$1

if ! [ -f $FRAMEWORK ]
then
	read -r -p "$FRAMEWORK not found, do I adb-pull? [y/N] " response	
	case $response in 
		[yY])
			adb pull /system/framework/$FRAMEWORK
			;;
		*)
			echo "Cannot work without $FRAMEWORK, exiting..."
			exit 1
	esac
fi

echo "installing framework"
apktool if $FRAMEWORK

echo "decompiling"
apktool d -f $APK
echo "done"
