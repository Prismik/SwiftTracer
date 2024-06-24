#!/bin/sh

mkdir docsData

xcodebuild -project SwiftTracer.xcodeproj \
	-derivedDataPath docsData \
	-scheme SwiftTracer \
	-destination 'platform=macOS' \
	-parallelizeTargets docbuild

mkdir archives

cp -R `find docsData -type d -name "*.doccarchive"` archives

$(xcrun --find docc) process-archive transform-for-static-hosting archives/SwiftTracer.doccarchive --hosting-base-path SwiftTracer --output-path docs

rm -rf docsData
rm -rf archives
