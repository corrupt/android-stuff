#!/bin/bash

# This script is a crude helper to deodex the camera APK from by Xperia Z5C
# and create a flashable ZIP to reflash again. I need to do this because the
# odexed camera crashes once XPosed is installed.
#
# The directory structure it expects is the following
# 
# system/priv-app   containing only the directories needed for deodexing (the apps)
#     -> mkdir -p system/priv-app/$APP && adb pull /system/priv-app/$APP system/priv-app/$APP
# system/framework  fully adb-pulled
#     -> mkdir -p system/framework && adb pull /system/framework system/framework
# 
# The classpath is extracted from /init.environ.rc on the phone
# 

WORKDIR=work
DISTDIR=dist
CLASSPATH=$(cat BOOTCLASSPATH | while read f; do echo -n :`basename $f`; done)
#CLASSPATH=${CLASSPATH%%:}
ZIPALIGN="/opt/android-sdk/build-tools/22/zipalign"
SDKVER=22

APPS="CameraCommon SemcCameraUI"

#echo "Classpath: $CLASSPATH"

for dir in $WORKDIR $DISTDIR; do
if [ -d $WORKDIR ]
then
  read -r -p "Directory $dir exists. Delete? [y/N] " response	
  case $response in 
		[yY])
				echo "Deleting $dir..."
				rm -rf $dir
				;;
		*)
				echo "Cannot use $dir. Exiting..."
				exit 1
esac
fi
done

rm -rf $WORKDIR
mkdir $WORKDIR

echo "Analyzing classpath"
cat BOOTCLASSPATH | while read f
do
	echo "Copying $f"	
	cp $f $WORKDIR
done

cp oat2dex.jar $WORKDIR
cp system/framework/arm64/boot.oat $WORKDIR
for app in $APPS; do
	echo "Collecting $app"
	cp system/priv-app/$app/$app.apk $WORKDIR
	if [ -d system/priv-app/$app/arm64 ]
	then 
		cp system/priv-app/$app/arm64/$app.odex $WORKDIR
	else 
		cp system/priv-app/$app/arm/$app.odex $WORKDIR
	fi
done

cd $WORKDIR

echo "Deodexing boot.oat"
#java -jar oat2dex.jar CameraCommon.odex CameraCommon.dex
#java -jar oat2dex.jar CameraCommon.odex classes.dex
java -jar oat2dex.jar boot boot.oat

for app in $APPS; do
	
	if [ -f $app.apk ]
	then
		echo "Deodexing $app"
		java -jar oat2dex.jar $app.odex dex
		mv $app.dex classes.dex

		#echo "Baksmaliying"
		#baksmali -a $SDKVER -c $CLASSPATH -x CameraCommon.dex -o deodex
		#
		#echo "Smalying"
		#smali -a $SDKVER deodex -o classes.dex

		echo "Adding to Archive"
		7za u -tzip $app.apk classes.dex

		echo "Zipaligning"
		cp $app.apk ${app}_nonaligned.apk
		$ZIPALIGN -f 4 ${app}_nonaligned.apk $app.apk
		$ZIPALIGN -c -v 4 $app.apk
	else
		echo cannot find $app
	fi

	echo "cleaning up"
	rm -rf deodex &> /dev/null
	rm $app_nonaligned.apk &> /dev/null
	rm classes.dex &> /dev/null
done
cd ..

echo "Generating dist structure"
for app in $APPS; do 
	mkdir -p dist/system/priv-app/$app	
	cp $WORKDIR/$app.apk dist/system/priv-app/$app
done
mkdir -p dist/com/google/android
cp updater-script dist/META-INF/com/google/android/
cp update-binary dist/META-INF/com/google/android/

cd dist
echo "Creating flashable ZIP"
jar -cf XperiaCameraDeodexed.zip *

echo "Signing ZIP"
signapk.sh XperiaCameraDeodexed.zip

echo "Adding installation files"
zip -r XperiaCameraDeodexed.zip META-INF

