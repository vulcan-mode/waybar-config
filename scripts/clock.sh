#!/bin/bash

day=$(date +%-d)

case "$day" in
1 | 21 | 31) suffix="st" ;;
2 | 22) suffix="nd" ;;
3 | 23) suffix="rd" ;;
*) suffix="th" ;;
esac

time=$(date "+%H:%M")
alt=$(date "+%A the $day$suffix of %B %Y, W%V")

printf '{"text":"%s","alt":"%s"}\n' "$time" "$alt"
