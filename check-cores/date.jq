.items[] |
if .href | contains($core + "_libretro")
then
    if (now - (.time / 1000)) > 60 * 60 * 24 * 3
    then
        .time/1000 | strftime("  Last built %Y-%m-%d")
    else
        empty
    end
else
    empty
end
