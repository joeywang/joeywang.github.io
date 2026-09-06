---
layout: post
title: "Self-Hosted Whisper: A Speech-to-Text API with Ruby and Kubernetes"
description: "How to run OpenAI's Whisper as a self-hosted speech-to-text REST API with Docker, a Ruby client, and a Kubernetes deployment for transcribing audio."
date: 2024-09-18 00:00 +0000
categories: [AI]
tags: [ai, ruby, docker, kubernetes]
---
<audio controls preload="metadata" src="/assets/audio/building-your-own-speech-to-text-service-with-whisper-summary.ogg">
  Your browser does not support the audio element.
</audio>


We produce English language learning material, and every audio file needs a transcript. Manual transcription is slow and error-prone, and sending thousands of files to a paid API adds up. So we self-hosted OpenAI's Whisper model behind a small REST API and wired it into our authoring tools.

Whisper earns its reputation. It is accurate across accents and background noise, and the transcripts are detailed enough to use directly in educational content.

## Wrapping Whisper in a REST API

Whisper is a Python model; our tooling is Ruby. The simplest boundary is HTTP. We run a Flask wrapper in Docker:

```bash
# Clone the repository
git clone https://github.com/reallyenglish-global/whisper-api-flask

# Build the Docker image
docker build . -t whisper

# Run the service
docker run -p 9000:5000 -e MODEL=small -d whisper

# Test the API
curl -F "file=@your_audio_file.mp3" http://0.0.0.0:9000/whisper
```

The `MODEL` variable selects the Whisper model size. Smaller models are faster and cheaper to host; larger ones are more accurate. `small` has been a reasonable middle ground for clear speech.

## A Ruby client

The client posts a multipart file upload and pulls the transcript out of the JSON response:

```ruby
# frozen_string_literal: true
require 'faraday'
require 'faraday/multipart'

class SpeechToText
  class ClientError < StandardError; end
  class ServerError < StandardError; end

  def self.enabled?
    ENV.fetch('WHISPER_ENDPOINT', '').present?
  end

  def convert(audio)
    audio = File.new(audio) if !audio.is_a?(File) && File.file?(audio)
    response = conn.post(endpoint, payload(audio.path))
    raise ServerError, "Error: #{response.status} - #{response.body}" unless response.success?

    results = response.body[:results]
    raise ClientError, 'No results found' if results.blank?

    results[0][:transcript]
  end

  private

  def conn
    @conn ||= Faraday.new do |f|
      f.request :multipart
      f.adapter :net_http
      f.headers['Content-Type'] = 'multipart/form-data'
      f.response :json, parser_options: { symbolize_names: true }
    end
  end

  def endpoint
    @endpoint ||= ENV.fetch('WHISPER_ENDPOINT', '')
  end

  def payload(file_path)
    {
      file: Faraday::Multipart::FilePart.new(file_path, 'audio/mp3'),
      response_format: 'verbose_json'
    }
  end
end
```

Usage from the application side:

```ruby
service = SpeechToText.new
transcript = service.convert('path/to/audio_file.mp3')
```

The `enabled?` check matters in practice: environments without a Whisper endpoint fall back to skipping transcription rather than failing.

## Deploying to Kubernetes

For production we run the API in our cluster:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whisper
  namespace: speech
  labels:
    app: whisper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: whisper
  template:
    metadata:
      labels:
        app: whisper
    spec:
      containers:
      - name: whisper
        image: ghcr.io/reallyenglish-global/whisper-api-flask
        imagePullPolicy: Always
        ports:
        - containerPort: 5000
        env:
        - name: MODEL
          value: base
        readinessProbe:
          httpGet:
            path: /
            port: 5000
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: whisper
  namespace: speech
spec:
  selector:
    app: whisper
  ports:
    - port: 5000
      targetPort: 5000
```

## Trade-offs to know before you copy this

- On CPU, transcription is slow. GPU acceleration changes the economics; without it, budget minutes per file, not seconds.
- The model holds a lot of memory. That is the real hosting cost, and it is why we run the `base` model in the cluster and `small` only where we can afford it.
- The API above has no authentication. Inside a cluster that is acceptable; anywhere else, put auth in front of it before someone else's audio bill becomes yours.
- Handle failure explicitly. Network errors, invalid audio, and empty results all happen, which is why the client raises typed errors instead of returning nil.

Self-hosting Whisper turned transcription from a manual chore into a call in our authoring pipeline. The model keeps improving upstream, so it is worth tracking releases: a model bump has so far been the cheapest accuracy improvement available.
