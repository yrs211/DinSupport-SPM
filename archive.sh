#!/bin/bash

cd DinSupportExample

xcodebuild archive \
-workspace DinSupportExample.xcworkspace \
-scheme DinSupport \
-configuration Release \
-sdk iphoneos \
-archivePath archives/ios_devices.xcarchive \
BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
SKIP_INSTALL=NO \

# 2
xcodebuild archive \
-workspace DinSupportExample.xcworkspace \
-scheme DinSupport \
-configuration Debug \
-sdk iphonesimulator \
-archivePath archives/ios_simulators.xcarchive \
BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
SKIP_INSTALL=NO \

# 3
xcodebuild \
-create-xcframework \
-framework archives/ios_devices.xcarchive/Products/Library/Frameworks/DinSupport.framework \
-framework archives/ios_simulators.xcarchive/Products/Library/Frameworks/DinSupport.framework \
-output DinSupport.xcframework
