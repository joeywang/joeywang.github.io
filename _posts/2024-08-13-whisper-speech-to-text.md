---
layout: post
title: "Whisper: An Open-Source Alternative to Cloud Speech-to-Text"
description: "OpenAI's Whisper is a self-hostable alternative to Google's Speech-to-Text API, with a Flask wrapper and a C++ port covered here alongside the original model."
date: 2024-08-13 14:41:26 +0100
categories: [AI]
tags: [ai, python, automation]
pin: true
---

[![Whisper demo video](https://img.youtube.com/vi/4pH_fPe50x0/0.jpg)](https://www.youtube.com/watch?v=4pH_fPe50x0)

<audio controls preload="metadata" src="/assets/audio/whisper-speech-to-text-summary.ogg">
  Your browser does not support the audio element.
</audio>

OpenAI's Whisper is a real alternative to Google's Speech-to-Text API when self-hosting or avoiding per-request billing matters more than managed convenience. Three links worth having: the model itself, a Flask wrapper that puts it behind an API, and a C++ port for running it without a Python runtime.

[OpenAI Whisper](https://github.com/openai/whisper)

[Whisper API Flask](https://github.com/lablab-ai/whisper-api-flask)

[Whisper.cpp](https://github.com/ggerganov/whisper.cpp)
