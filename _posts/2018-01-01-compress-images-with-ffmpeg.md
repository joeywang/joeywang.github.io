---
layout: post
title: Compress Images with FFMPEG
date: 2018-01-01 00:00 +0000
description:
image:
category:
tags:
published: false
sitemap: false
---
```bash
# compress image with scale
ffmpeg -i test.mp4 -vf scale=320:240 small.mp4


# compress image
ffmpeg -i input.jpg -vf scale=320:240 output_320x240.png

ffmpeg -i input.jpg -vf scale=iw*2:ih input_double_width.png

ffmpeg -i input.jpg -vf scale=iw*.5:ih*.5 input_half_size.png

ffmpeg -i input.jpg -vf scale="'if(gt(a,4/3),320,-1)':'if(gt(a,4/3),-1,240)'" output_320x240_boxed.png

ffmpeg -i input.jpg -vf scale=w=320:h=240:force_original_aspect_ratio=decrease output_320.png
```
