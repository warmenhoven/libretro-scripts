.items[] |
if .href | contains("_libretro")
then
    (.href | sub(".*\\/(?<a>.*)_libretro.*"; "\(.a)"))
else
    empty
end
