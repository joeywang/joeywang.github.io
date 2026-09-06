---
layout: post
title: "Debugging an IP camera's RTSP live stream URL"
description: "Most IP cameras advertise RTSP support without documenting a working stream URL, and this walks through finding one with ffmpeg, nmap, and the vendor web UI."
date: 2025-12-04
tags: [ip-camera, rtsp, ffmpeg, networking]
categories: [Notes]
---

<audio controls preload="metadata" src="/assets/audio/rtsp-live-streaming-summary.ogg">
  Your browser does not support the audio element.
</audio>

Many IP cameras advertise "RTSP support", yet finding a working live stream URL is often undocumented, inconsistent, or buried in vendor UI. This is a command-line-first approach to discovering, debugging, and validating an IP camera's stream, without cloud access or vendor SDKs, for a camera already on your LAN.

Typical symptoms: RTSP is enabled but playback fails, you get `461 Unsupported Transport`, authentication is confusing, or the stream works in the vendor's app but nowhere else.

## Step 1: identify the camera on the LAN

ARP is more reliable than ping for finding IoT devices:

```bash
sudo arp-scan --localnet
```

Look for a fixed MAC and vendor OUI (or unknown OEM):

```
192.168.0.100  6a:12:1b:29:10:81  (Unknown)
```

Then scan its ports:

```bash
nmap 192.168.0.100
```

A typical IP camera profile:

```
80/tcp   open  http
443/tcp  open  https
554/tcp  open  rtsp
8899/tcp open  unknown
9898/tcp open  unknown
```

That tells you a web UI exists, RTSP exists, and there are vendor-private services you probably don't need.

## Step 2: confirm RTSP is standards-compliant

Before guessing URLs, check the server actually speaks RTSP:

```bash
nmap --script rtsp-methods -p 554 192.168.0.100
```

Expect `OPTIONS, DESCRIBE, SETUP, PLAY, PAUSE, TEARDOWN` back. If you get that, failures downstream are about the URL path or transport, not a missing protocol.

## Step 3: enable RTSP in the web UI

Open the camera's local UI (for example `http://192.168.0.100/apcam/index.asp`) and look for RTSP enable/disable and an authentication mode: disabled, basic, or digest. While you're finding the stream path, temporarily set authentication to disabled so it isn't a second variable alongside the URL.

## Step 4: the most common failure

```
method DESCRIBE failed: 461 Unsupported Transport
```

This means the RTSP server exists and responded, but your transport negotiation is wrong. It is not an authentication problem, even though it's tempting to assume it is.

## Step 5: force TCP transport

Many cameras don't handle UDP RTP cleanly. Force TCP-interleaved RTSP first:

```bash
ffmpeg -rtsp_transport tcp -i rtsp://192.168.0.100:554/...
```

This alone resolves a lot of `461` errors.

## Step 6: try known URL patterns

There's no universal RTSP path, so work through the common ones systematically:

```text
/Streaming/Channels/101        (main stream)
/Streaming/Channels/102        (sub stream)
/cam/realmonitor?channel=1&subtype=0
/cam/realmonitor?channel=1&subtype=1
/h264Preview_01_main
/h264Preview_01_sub
/stream=0
/stream=1
```

Test each with TCP forced:

```bash
ffmpeg -rtsp_transport tcp -i rtsp://192.168.0.100:554/Streaming/Channels/101
```

`401 Unauthorized` means the path is right and auth is required. Frames appearing means success. `461` or `404` means wrong path, try the next one.

## Step 7: let the web UI hand you the path

Most cameras expose the RTSP path indirectly through their own frontend. Open the web UI, open dev tools' Network tab, click preview or live view, and watch for `rtsp`, `stream`, `channel`, or `media` in the requests. You'll often find a CGI endpoint that returns the RTSP path and its parameters directly. This is just using the device's own API, not reverse engineering anything.

## Step 8: recording pitfalls

Always give the output file an extension; `ffmpeg ... record` with no extension will confuse the muxer, `ffmpeg ... record.mkv` won't.

A common error when writing to MP4:

```
Could not find tag for codec pcm_alaw
```

The camera's audio is G.711 (pcm_alaw), which MP4 doesn't support. Options, best to worst:

```bash
# No re-encode, keep everything (use MKV)
ffmpeg -rtsp_transport tcp -i rtsp://... -c copy record.mkv

# MP4 without audio
ffmpeg -rtsp_transport tcp -i rtsp://... -an -c copy record.mp4

# MP4 with audio transcoded
ffmpeg -rtsp_transport tcp -i rtsp://... -c:v copy -c:a aac record.mp4
```

## Step 9: restore security

Once you have the working URL, don't leave it open. Re-enable RTSP digest authentication, use a dedicated RTSP user, block WAN access to the camera, and close the unused vendor ports (8899, 9898, whatever nmap found). Validate that the unauthenticated URL now fails and the authenticated one still works:

```bash
# Should fail
ffmpeg -rtsp_transport tcp -i rtsp://192.168.0.100:554/...

# Should succeed
ffmpeg -rtsp_transport tcp -i rtsp://user:pass@192.168.0.100:554/...
```

Debugging an IP camera stream isn't about guessing URLs, it's about removing variables one at a time: confirm the service, control the transport, find the path, validate with standard tools, then put security back. Any RTSP-capable camera can be integrated locally and cloud-free this way.
