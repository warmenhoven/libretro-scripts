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
        #curl -s --header "$auth" "$urlbase/projects/$i/pipelines/latest" | jq -r 'if (.message or isempty(.status)) then empty else if (.status != "success") then .status + ": " + .web_url else empty end end'
        echo $i
    ) &
done
wait
