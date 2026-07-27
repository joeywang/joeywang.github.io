---
layout: post
title: "Voice Control for Hermes Agent over Telegram"
date: 2026-07-27 09:00:00 +0100
author: "Joey Wang"
description: "How I wired Hermes Agent to accept Telegram voice notes, transcribe them locally, and reply with local text-to-speech without adding another paid speech API."
tags: [hermes, ai-agents, telegram, voice, speech-to-text, text-to-speech, devops]
categories: [AI, DevOps]
---

# Voice control for Hermes Agent over Telegram

<audio controls preload="metadata" src="/assets/audio/2026-07-27-voice-control-for-hermes-over-telegram-summary.ogg">
  Your browser does not support the audio element.
</audio>

The small annoyance was typing.

I already had Hermes running as a Telegram bot, which meant I could reach it from my phone. That was useful for quick checks, calendar questions, and background jobs. But the mobile workflow still had friction: unlock phone, open the chat, type a long enough message, correct autocorrect, send.

For an assistant that is supposed to fit into daily operations, that is just enough friction to avoid using it.

So I wired the voice path instead:

```text
Android Telegram voice note
  -> Telegram bot update
  -> Hermes gateway
  -> local speech-to-text
  -> normal Hermes agent turn
  -> optional text-to-speech reply
  -> Telegram voice bubble
```

The important part is not that the bot can speak. The important part is that the speech layer does not need to become another paid cloud dependency. In my setup, transcription runs locally with faster-whisper and speech output runs locally with Piper.

## The two different meanings of "voice"

There are two voice experiences people tend to mix together.

The first is a **voice message workflow**. You send a Telegram voice note to the bot. Hermes downloads the audio, transcribes it, and injects the transcript into the conversation as if you had typed it. If TTS is enabled, Hermes can send the answer back as an audio bubble.

The second is a **live voice call**. That is a different product shape. Telegram bots are message bots; they are not normal phone-call participants. For live voice rooms, Discord voice channels are a better fit in Hermes today.

For my phone workflow, Telegram voice notes are enough. I want capture on the move, not a continuous call.

## What needs to be installed

For a local speech stack, Hermes needs three pieces:

- the messaging dependencies for Telegram;
- a speech-to-text backend;
- a text-to-speech backend plus audio conversion for Telegram voice bubbles.

On Ubuntu, the system packages are boring but important:

```bash
sudo apt install ffmpeg
```

`ffmpeg` matters because Telegram voice bubbles are Opus inside OGG. Some TTS providers output that directly. Others output MP3, WAV, or PCM and need conversion before Telegram can show a proper voice bubble.

For Hermes' Python side, install the voice/messaging extras from the Hermes checkout:

```bash
cd ~/.hermes/hermes-agent
uv pip install -e ".[voice]"
uv pip install -e ".[messaging]"
uv pip install -U piper-tts
```

The local STT path uses `faster-whisper`. The local TTS path here uses `piper`.

## The config I wanted

The goal was simple:

```text
No extra paid STT API.
No extra paid TTS API.
Keep voice useful on a small CPU box.
```

My Hermes config ended up with this shape:

```yaml
stt:
  enabled: true
  provider: local
  local:
    model: base

tts:
  provider: piper
  piper:
    voice: en_US-lessac-medium

voice:
  auto_tts: false
  response_mode: note
  note_dir: /path/to/voice-notes
```

The `base` faster-whisper model is a practical default. It is not the most accurate Whisper model, but it is fast enough for short Telegram voice notes and small enough to run comfortably on a CPU-only server.

Piper is similar. It is not a premium studio voice, but it is local, predictable, and cheap to run. For an operational assistant, I care more about reliability and cost than a perfect narrator voice.

## Telegram wiring

The Telegram side starts with BotFather.

Create a bot, get the token, and put it in the Hermes environment file:

```bash
# ~/.hermes/.env
TELEGRAM_BOT_TOKEN="<bot-token-from-botfather>"
```

Do not commit that file. Do not paste the real token into docs, logs, or screenshots.

Then run the gateway:

```bash
hermes gateway run
```

For a long-running server, I prefer a user systemd service so the bot survives SSH disconnects:

```bash
systemctl --user enable --now hermes-gateway
systemctl --user status hermes-gateway --no-pager -l
```

If the service dies when the SSH session exits, enable user lingering:

```bash
sudo loginctl enable-linger "$USER"
```

## The port question

Telegram can be wired in two common ways.

The simpler path is **long polling**. Hermes connects out to Telegram and asks for updates. In that mode, there is no public inbound port to open for Telegram. This is usually the easiest setup for a personal bot on a VPS.

The other path is a **webhook**. Telegram sends HTTPS requests to your server when new messages arrive. That requires a public HTTPS URL and firewall/reverse-proxy routing.

A webhook setup has two port numbers that people often confuse:

```text
Telegram public URL
  https://bot.example.com/<secret-path>
        |
        v
Reverse proxy / firewall on 443
        |
        v
Local Hermes webhook listener on <local-port>
```

The public port and the local port do not have to be the same. Telegram only cares that the webhook URL is publicly reachable over HTTPS. Your reverse proxy can terminate TLS on 443 and forward to a local Hermes listener on another port.

If voice notes are not arriving, I would check these in order:

```bash
# Is the gateway alive?
systemctl --user status hermes-gateway --no-pager -l

# Does Hermes see Telegram errors?
grep -i "telegram\|voice\|transcrib\|error" ~/.hermes/logs/gateway.log | tail -50

# Is STT enabled?
hermes config get stt.enabled
hermes config get stt.provider
hermes config get stt.local.model

# Is ffmpeg installed?
ffmpeg -version | head -1
```

For webhook mode, also test the public URL from outside the server:

```bash
curl -I https://bot.example.com/<secret-path>
```

If that URL is not reachable over HTTPS, Telegram will not deliver updates to it.

## Android Telegram gotcha

The first failure I hit was not Hermes at all. It was Telegram's UI.

On Android, the bottom-right button in the chat input can toggle between a microphone and a camera/video-message icon. If there is text in the input box, Telegram shows a send arrow instead. So the voice button may look like it has disappeared.

The fix is simple:

1. clear the text input;
2. tap the camera/video icon once if it is showing;
3. press and hold the microphone;
4. send a short voice note to the bot.

You do not need a special Hermes voice command in the Telegram bot menu. A normal Telegram voice note is the input.

## Verifying the local path

I like making this explicit because it is easy to think voice means another API bill.

The verification commands are plain:

```bash
hermes config get stt.enabled
hermes config get stt.provider
hermes config get stt.local.model
hermes config get tts.provider
hermes config get tts.piper.voice
```

For the setup described here, the expected values are:

```text
true
local
base
piper
en_US-lessac-medium
```

I also check that the packages are installed inside the Hermes environment:

```bash
~/.hermes/hermes-agent/venv/bin/python - <<'PY'
import importlib.util
for name in ["faster_whisper", "piper"]:
    print(name, "OK" if importlib.util.find_spec(name) else "missing")
PY
```

And then I do the real test: send a voice note from Telegram.

A good first test is short and unambiguous:

```text
Hermes, can you hear this voice note?
```

If Hermes answers the content of the message, STT is working. If the reply arrives as a playable Telegram voice bubble, TTS delivery is working too.

## Cost and privacy tradeoff

This setup does not make the whole assistant free. The agent still uses whatever LLM provider is configured for the actual reasoning turn.

But the speech layer itself is local:

```text
Speech-to-text: local faster-whisper
Text-to-speech: local Piper
Audio conversion: local ffmpeg
```

That means short voice notes do not need to go to OpenAI, ElevenLabs, Groq, or another speech API just to become text or audio. The tradeoff is that CPU time and quality are now your problem. For my use case, that is a good trade.

If I wanted more natural speech later, I would treat it as a separate ladder:

- keep faster-whisper local for input;
- try Edge TTS if I want a free online voice with better quality;
- use a paid provider only when the voice quality matters;
- consider a heavier local model only if I have GPU resources and a reason.

## What this changes

The useful outcome is not novelty. It is lowering the cost of capture.

I can now send Hermes a rough voice note while walking, cooking, or away from the keyboard. The transcript becomes a normal agent request. If I want the answer spoken back, Hermes can send audio into the same Telegram chat.

That turns Telegram from "remote text box for my agent" into a lightweight voice front-end for my personal infrastructure.

It is still just messages. That is the point. Message-based voice is easier to operate, easier to audit, and easier to secure than a live always-listening assistant.
