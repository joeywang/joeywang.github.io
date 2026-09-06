---
layout: post
title: "Linux kill signals: graceful shutdown in containerized workers"
description: "SIGTERM, SIGKILL, and grace periods control whether a containerized worker finishes its job before Kubernetes or Supervisord kills it outright."
date: 2024-11-26 22:54 +0000
categories: [DevOps]
tags: [linux, kubernetes, docker, devops]
---
<audio controls preload="metadata" src="/assets/audio/mastering-linux-kill-signals-graceful-shutdown-in-containerized-worker-environments-2024-11-24-summary.ogg">
  Your browser does not support the audio element.
</audio>


A worker process that gets SIGKILL mid-job doesn't get a chance to finish, checkpoint, or even log what it was doing. In a containerized environment, that's the default outcome unless you handle SIGTERM explicitly and give the process a grace period to act on it before the orchestrator escalates to SIGKILL.

## The signals that matter

| Signal | Name | Meaning | Default action |
|--------|------|---------|-----------------|
| SIGTERM (15) | Terminate | Please shut down | Terminate process |
| SIGKILL (9) | Kill | Shut down now, no cleanup | Immediately stop process |
| SIGINT (2) | Interrupt | Ctrl+C | Terminate process |
| SIGHUP (1) | Hangup | Reload config, or terminate | Terminate process |

Kubernetes and Docker both send SIGTERM first, wait out a grace period, then send SIGKILL if the process is still alive. Everything below is about using that window.

## Handling SIGTERM in the worker itself

Sidekiq already does this:

```ruby
Sidekiq.configure_server do |config|
  config.on(:shutdown) do
    puts "Gracefully shutting down Sidekiq"
  end
end
```

A Laravel queue worker needs the signal handler registered explicitly, since PHP doesn't trap signals unless you ask it to:

```php
public function handle()
{
    pcntl_signal(SIGTERM, function () {
        $this->shouldStop = true;
    });

    while (!$this->shouldStop) {
        $this->processNextJob();
    }
}
```

## Giving the process time to act

Docker Compose and Kubernetes both let you extend the grace period:

```yaml
# docker-compose.yml
services:
  worker:
    stop_grace_period: 30s
    stop_signal: SIGTERM
```

```yaml
# Kubernetes
spec:
  template:
    spec:
      containers:
      - name: worker
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 30"]
```

The grace period only helps if the worker is actually listening for SIGTERM. Extending `stop_grace_period` on a worker that ignores the signal just delays the SIGKILL by 30 seconds for nothing.

## Supervisord as the signal relay

When Supervisord manages the worker instead of the container runtime talking to it directly, the signal has to pass through Supervisord first:

```
Container termination signal (SIGTERM)
  -> Supervisord
    -> supervised processes
      -> application shutdown
```

`stopasgroup` and `killasgroup` are what make that forwarding actually happen, rather than Supervisord catching the signal and leaving its children running:

```ini
[program:worker]
command=/usr/bin/php /app/artisan queue:work
autostart=true
autorestart=true
stopwaitsecs=30
stopsignal=SIGTERM
stopasgroup=true
killasgroup=true
```

A wrapper script that traps SIGTERM directly gives more control over the shutdown sequence than Supervisord's defaults alone:

```bash
#!/bin/bash

trap_sigterm() {
    echo "Received SIGTERM. Initiating graceful shutdown..."
    supervisorctl stop all
    wait_for_workers_shutdown
    cleanup_resources
    exit 0
}

wait_for_workers_shutdown() {
    timeout=30
    while [ $timeout -gt 0 ]; do
        active_workers=$(supervisorctl status | grep -E "RUNNING|STARTING" | wc -l)
        if [ $active_workers -eq 0 ]; then
            echo "All workers have shutdown successfully"
            return 0
        fi
        sleep 1
        ((timeout--))
    done
    echo "Some workers did not shutdown in time"
    return 1
}

cleanup_resources() {
    rm -rf /tmp/worker-*
    echo "Cleanup complete"
}

trap trap_sigterm SIGTERM
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
```

## What tends to go wrong

Zombie processes show up when nothing is acting as PID 1 correctly, usually solved by an init wrapper such as `tini`, or by Supervisord itself in that role. Incomplete shutdowns are almost always a grace period that's shorter than the actual cleanup work takes, not a bug in the trap logic. Test the shutdown path under load, not just at rest, since a worker mid-job behaves differently than one sitting idle when SIGTERM arrives.
