#!/bin/bash

auth="Authorization: Bearer $PRIVATE_TOKEN"
urlbase='https://git.libretro.com/api/v4'

projects=""
projects+=$(curl -s --header "$auth" "$urlbase/projects?per_page=100&page=1" | jq -r '.[].path_with_namespace')
projects+=" "
projects+=$(curl -s --header "$auth" "$urlbase/projects?per_page=100&page=2" | jq -r '.[].path_with_namespace')
projects+=" "
projects+=$(curl -s --header "$auth" "$urlbase/projects?per_page=100&page=3" | jq -r '.[].path_with_namespace')
for i in $projects ; do
    (
        mirr=$(curl -s --header "$auth" -o - "https://git.libretro.com/$i/-/branches" | grep "This project is mirrored from")
        if [ -n "$mirr" ] ; then
            echo "$i: $mirr"
        fi
    )
done
wait

