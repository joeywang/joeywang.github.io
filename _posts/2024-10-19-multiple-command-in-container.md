---
layout: post
title: "Running Multiple Processes in a Single Container"
description: "Six ways to run multiple processes in one Docker container, from GNU Parallel and Foreman to a custom entrypoint script, Supervisord, and tmux, with trade-offs."
date: 2024-10-19 00:00 +0000
categories: [DevOps]
tags: [docker, devops, debugging]
---

<audio controls preload="metadata" src="/assets/audio/multiple-command-in-container-summary.ogg">
  Your browser does not support the audio element.
</audio>


Debugging a Rails app from VSCode while the Rails server itself needs to keep running is a common case: the container has to run `rdbg`, the Ruby debug listener, and `rails server` at the same time. `CMD` and `ENTRYPOINT` only take one process, so something has to manage the rest. Here's what each option actually costs you.

## GNU Parallel

```
RUN apt-get update && apt-get install -y parallel
```

```
CMD parallel ::: "rdbg -n --open --host 0.0.0.0 --port 12345" "rails server -b 0.0.0.0"
```

Simple, but it's one more dependency for something that doesn't need a job-parallelization tool: Parallel is built for fan-out batch work, not for supervising two long-running services.

## Foreman with a Procfile

```
RUN gem install foreman
```

```
debugger: rdbg -n --open --host 0.0.0.0 --port 12345
web: rails server -b 0.0.0.0
```

```
CMD ["foreman", "start"]
```

The natural choice in a Ruby project: it's already part of the ecosystem, and it gives you unified, prefixed logs for both processes with no extra configuration.

## A custom entrypoint script

```bash
#!/bin/bash
set -e

rdbg -n --open --host 0.0.0.0 --port 12345 &
rails server -b 0.0.0.0

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
```

```
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

No extra dependency, and full control over startup order and exit behavior, at the cost of a script you now own and have to keep correct. That's usually the right trade when the process logic is genuinely simple, as it is here.

## Supervisord

```
RUN apt-get update && apt-get install -y supervisor
```

```
[supervisord]
nodaemon=true

[program:debugger]
command=rdbg -n --open --host 0.0.0.0 --port 12345
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:rails]
command=rails server -b 0.0.0.0
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
```

```
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
```

Supervisord restarts processes automatically and centralizes logging, which is what you want in production. For a local debugging setup, that's more process than the problem needs.

## tmux

```
RUN apt-get update && apt-get install -y tmux
```

```bash
#!/bin/bash
tmux new-session -d -s myapp 'rdbg -n --open --host 0.0.0.0 --port 12345'
tmux split-window -v 'rails server -b 0.0.0.0'
tmux attach-session -d
```

Useful if you actually want an interactive terminal into the container, less useful if you just want both processes running in the background. Not something to ship to production.

## Docker Compose

Not a way to run multiple commands in one container, but often the better answer to the underlying problem: give the debugger and the server their own containers.

```yaml
version: '3'
services:
  debugger:
    image: your-rails-image
    command: rdbg -n --open --host 0.0.0.0 --port 12345
    ports:
      - "12345:12345"
  web:
    image: your-rails-image
    command: rails server -b 0.0.0.0
    ports:
      - "3000:3000"
```

```
docker-compose up
```

## Which one to actually use

For the VSCode-plus-rdbg case specifically, a custom entrypoint script or Foreman covers it with the least added complexity. Reach for Supervisord only once this is running in production and needs automatic restarts. tmux and Docker Compose solve different problems, interactive access and container separation, not "run two commands in one container" as such.
