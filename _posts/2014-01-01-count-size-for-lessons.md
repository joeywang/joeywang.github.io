---
layout: post
title: count file size from json
date: 2014-01-01 00:00 +0000
categories: Bash
tags: script
---

```bash
set -o nounset                              # Treat unset variables as an error

for f in ../json/lesson_[0-9]*.json
#for f in ../json/lesson_1608905.json
do
  lesson_id=${f:15:7}
  out=`jq '..|select(objects and has("resourceType") and (.resourceType|length>0)).resourceID' $f|xargs du -chk ../activity/*|tail -n 1 |awk -F ' ' '{print ($1-501)}'`
  echo "$lesson_id ${out}K"
done
```
