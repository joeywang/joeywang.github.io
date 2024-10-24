---
layout: post
title: How to Debug Docker Image Builds
date: 2024-10-21 00:00 +0000
tags: [debug, docker, image, build]
---

# How to Debug Docker Image Builds

This guide covers various techniques to debug Docker image builds, from basic to advanced approaches.

## Common Debugging Scenarios

### 1. Using BuildKit's Enhanced Debugging Features

BuildKit (the default builder in modern Docker) offers several powerful debugging options:

```bash
# Enable detailed debugging output
BUILDKIT_STEP_LOG_MAX_SIZE=-1 docker build .

# Continue build after error (buildx feature)
docker buildx build --progress=plain --on-error=continue .

# Print verbose output
docker buildx build --progress=plain .
```

### 2. Debugging Failed Layers

#### 2.1 Remove Problematic Commands
If you have a failing command like:
```Dockerfile
FROM busybox
RUN echo 'hello world' > /tmp/test
RUN exit 1  # problematic command
RUN echo 'ready'
```
Simply remove the failing command and subsequent commands:
```Dockerfile
FROM busybox
RUN echo 'hello world' > /tmp/test
```

#### 2.2 Inspect Intermediate Layers
Turn off BuildKit to see layer SHA:
```bash
DOCKER_BUILDKIT=0 docker build -t test .
# Use the SHA of the last successful layer
docker run --rm -it <sha> sh
```

### 3. Interactive Debugging with `nsenter`

#### 3.1 Basic nsenter Debugging
```Dockerfile
FROM busybox
RUN echo 'hello world'
RUN sleep infinite  # Add this for debugging
RUN exit 1
```

```bash
# In terminal 1: Start the build
docker build -t test .

# In terminal 2: Enter the container's namespace
docker run -it --rm --privileged --pid=host justincormack/nsenter1
ps -ef | grep sleep
nsenter -p -m -u -i -n -t <PID> sh
```

#### 3.2 Alternative nsenter Approach with Alpine
```bash
docker run --privileged --pid=host -it alpine \
nsenter -t 1 -m -u -n -i sh
```

### 4. Multi-stage Build Debugging

#### 4.1 Basic Target Approach
```Dockerfile
FROM busybox as working
RUN echo 'hello world'

FROM working as error
RUN exit 1
```

```bash
# Build specific target
docker build -t test --target working .
# Debug the working stage
docker run --rm -it test sh
```

#### 4.2 Advanced Multi-stage Debugging
```Dockerfile
# Development stage with debugging tools
FROM ruby:3.2 as development
RUN apt-get update && \
    apt-get install -y vim curl htop

# Production stage
FROM ruby:3.2-slim as production
COPY --from=development /app /app
```

### 5. BuildKit Debug Features

#### 5.1 Mount Cache
```Dockerfile
# Cache apt packages
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y build-essential
```

#### 5.2 Secret Mounting
```Dockerfile
# Mount secrets during build
RUN --mount=type=secret,id=mysecret cat /run/secrets/mysecret
```

### 6. Debugging Ruby on Rails Specific Issues

Here's an improved version of the Rails Dockerfile with debugging considerations:

```Dockerfile
FROM ruby:3.2

# Install essential libraries
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y \
    libssl-dev \
    postgresql-client \
    nodejs \
    npm

# Set working directory
WORKDIR /app

# Install debugging tools in development
ARG RAILS_ENV=development
RUN if [ "$RAILS_ENV" = "development" ]; then \
    gem install debase ruby-debug-ide; \
    fi

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Install JavaScript dependencies
COPY package.json yarn.lock ./
RUN npm install -g yarn && yarn install

# Copy application code
COPY . .

# Start Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

## Best Practices

1. **Layer Caching**
   - Use multi-stage builds to separate build dependencies
   - Order Dockerfile commands from least to most frequently changing
   - Use .dockerignore to exclude unnecessary files

2. **Debugging Tools**
   - Include debugging tools only in development stages
   - Use BuildKit's cache mounts for package managers
   - Leverage BuildKit's --progress=plain for detailed build output

3. **Security**
   - Never leave debugging tools in production images
   - Use secrets mounting for sensitive data
   - Regular security scanning of base images

## Common Issues and Solutions

1. **Bundle Install Failures**
   ```bash
   # Debug bundle install
   docker run --rm -it <image-id> bundle install --verbose
   ```

2. **Permission Issues**
   ```bash
   # Fix permission problems
   RUN chown -R user:user /app
   USER user
   ```

3. **Network Issues**
   ```bash
   # Test network connectivity
   docker run --rm -it <image-id> ping -c 3 google.com
   ```

## Additional Tools

1. **Docker Dive**
   ```bash
   # Analyze image layers
   dive <image-name>
   ```

2. **Docker History**
   ```bash
   # View layer history
   docker history --no-trunc <image-name>
   ```

Remember to always clean up debugging artifacts before pushing to production:
```bash
# Remove debugging layers
docker image prune -f
```
