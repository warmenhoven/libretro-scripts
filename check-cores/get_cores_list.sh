#!/bin/bash

for target in apple/ios9 apple/ios-arm64 apple/osx/arm64 apple/osx/x86_64 apple/tvos-arm64 windows/x86_64 ; do
    outname=$(echo $target | sed -e 's/\//./g')
    echo Fetching $target to $outname
    curl -s -d "{\"action\":\"get\",\"items\":{\"href\":\"/nightly/$target/latest/\",\"what\":1}}" https://buildbot.libretro.com/? | \
        tee $outname.int | \
        jq -r -f filter.jq > $outname
    #     tee $outname.int | \
    #     jq ".items[].href" | \
    #     sed -e 's/_ios\././' | \
    #     sed -e 's/_tvos\././' | \
    #     sed -e 's/_android\././' | \
    #     sed -e 's/\.dll/.dylib/' | \
    #     sed -e 's/\.so/.dylib/' | \
    #     grep dylib | \
    #     sed -e 's/.*\/\(.*\)"/\1/g' > $outname

done

outname=android.arm64-v8a
echo Fetching android/latest/arm64-v8a to $outname
curl -s -d "{\"action\":\"get\",\"items\":{\"href\":\"/nightly/android/latest/arm64-v8a/\",\"what\":1}}" https://buildbot.libretro.com/? | \
    tee $outname.int | \
    jq -r -f filter.jq > $outname
    # jq ".items[].href" | \
    # sed -e 's/_android\././' | \
    # sed -e 's/\.so/.dylib/' | \
    # grep dylib | \
    # sed -e 's/.*\/\(.*\)"/\1/g' > $outname

function dgs() {
    for core in $(diff -u $1 $2 | grep '^-[^-]' | cut -b 2-) ; do
        echo $core | sed -e 's/^/- [ ] /'
        jq -r -f date.jq --arg core $core $1.int
    done
}

echo "** Cores that are on Windows x86_64 but not OSX x86_64"
dgs windows.x86_64 apple.osx.x86_64

echo "** Cores that are available for OSX x86_64 but not arm64"
dgs apple.osx.x86_64 apple.osx.arm64

echo "** Cores that are available for OSX arm64 but not iOS"
dgs apple.osx.arm64 apple.ios-arm64

echo "** Cores that are available for iOS but not tvOS"
dgs apple.ios-arm64 apple.tvos-arm64

echo "** Cores that are available for iOS9 but not iOS-arm64"
dgs apple.ios9 apple.ios-arm64

echo "** Cores that are available for Android but not OSX x86_64"
dgs android.arm64-v8a apple.osx.x86_64
