---
layout: post
title: Building Your Own Speech-to-Text Service with Whisper
date: 2024-09-18 00:00 +0000
categories: [AI]
tags: [Ruby]
---
# Building Your Own Speech-to-Text Service with Whisper

## Introduction

In the realm of English language learning, transcribing audio files is a crucial yet time-consuming task. Manual transcription is not only laborious but also prone to errors. This article explores how to streamline this process by leveraging Speech-to-Text (STT) technology, specifically focusing on building a service using the open-source Whisper model.

## Understanding Whisper

Whisper is an innovative open-source speech recognition model developed by researchers at OpenAI (not Mozilla as previously stated). It has gained popularity due to its:

- High accuracy across multiple languages
- Ability to handle diverse accents and background noises
- Detailed transcriptions suitable for educational purposes

## Creating a REST API for Whisper

To make Whisper more accessible and integrate it into our authoring tools, we'll wrap it in a REST API. This approach allows for easy scalability and integration with various applications.

### Setting Up the Whisper API

Follow these steps to set up the Whisper API using Docker:

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

## Developing a Ruby Client

To interact with our Whisper API, we'll create a Ruby client. This client will handle API communication and process transcription results.

### Ruby Client Implementation

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

## Deploying to Kubernetes

For production environments, deploying the Whisper API within a Kubernetes cluster ensures scalability and reliability.

### Kubernetes Deployment Configuration

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

### Kubernetes Service Configuration

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

## Integrating the Service

Incorporating the Whisper API into your application is straightforward with the Ruby client:

```ruby
service = SpeechToText.new
transcript = service.convert('path/to/audio_file.mp3')
# Process the transcript as needed
```

## Considerations and Optimizations

While Whisper offers a powerful solution for speech transcription, consider the following:

1. **Performance**: GPU acceleration significantly improves processing speed.
2. **Resource Usage**: The model requires substantial memory, impacting hosting costs.
3. **Scalability**: Different model sizes offer trade-offs between accuracy and resource consumption.
4. **API Security**: Implement authentication to control access to your API.
5. **Error Handling**: Implement robust error handling for various scenarios (network issues, invalid audio files, etc.).

## Future Enhancements

To further improve the service, consider:

1. **Implementing Caching**: Store frequently requested transcriptions to reduce processing load.
2. **Adding Language Detection**: Automatically detect the spoken language for multi-language support.
3. **Integrating Analytics**: Track usage patterns to optimize resource allocation.
4. **Implementing Batch Processing**: Allow multiple audio files to be processed in a single request.

## Conclusion

Building a custom Speech-to-Text service using Whisper can significantly enhance the efficiency of creating English learning resources. By following this guide, you can create a robust, scalable solution tailored to your specific needs, making the transcription process more accurate and less time-consuming.

Remember to stay updated with the latest developments in the Whisper project, as continuous improvements may offer new features and enhanced performance over time.
