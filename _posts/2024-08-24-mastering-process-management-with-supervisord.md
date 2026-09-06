---
layout: post
title: "Supervisord: Process Management for Containers and VMs"
description: "How supervisord monitors and restarts UNIX processes through simple INI-style config, with a working example for MySQL, PHP, and an init script."
date: 2024-08-24 00:00 +0000
categories: [DevOps]
tags: [supervisord, linux, devops, container]
---

<audio controls preload="metadata" src="/assets/audio/mastering-process-management-with-supervisord-summary.ogg">
  Your browser does not support the audio element.
</audio>

`supervisord` is a Python process control system for monitoring and restarting UNIX processes, configured through plain INI files. It's a common choice inside a container that needs to run more than one process, since Docker itself only supervises PID 1.

## Installation

Install it with your OS package manager, or from source if you need a specific version.

## Basic configuration

The config file usually lives at `/etc/supervisor/supervisord.conf`. It has a section for `supervisord` itself, then one `[program:name]` section per process it manages:

```ini
[supervisord]
nodaemon=true ; Run supervisord as a foreground process

[program:mysqld]
command=mysqld_safe ; Start the MySQL server

[program:php-server]
command=php -S 0.0.0.0:8000 -t /opt/app/ ; Start a PHP development server
autostart=true ; Automatically start the program when supervisord starts
autorestart=true ; Automatically restart the program if it exits
stderr_logfile=/var/log/php-server.err.log ; Log errors to this file
stdout_logfile=/var/log/php-server.out.log ; Log output to this file

[program:init_script]
command=/usr/local/bin/init_script.sh ; Run a custom initialization script
autostart=false ; Do not start the program automatically
startsecs=0 ; Number of seconds to wait after starting the process before sending a status check
autorestart=false ; Do not automatically restart the program if it exits
redirect_stderr=true ; Redirect standard error to standard output
stdout_logfile=/var/log/supervisor/init_script.log ; Log output to this file
stderr_logfile=/var/log/supervisor/init_script.err ; Log errors to this file
```

## Key options

- `nodaemon`: run in the foreground instead of daemonizing. Set this to `true` when `supervisord` is PID 1 in a container.
- `command`: the command that starts the program.
- `autostart`: start automatically when `supervisord` starts.
- `autorestart`: restart automatically if the process exits.
- `stderr_logfile` / `stdout_logfile`: where each stream gets written.

For more advanced setups, `supervisord` also supports environment variables per program, process priorities (controlling start/stop order), and event listeners.

## Controlling processes

`supervisorctl` is the command-line client for talking to a running `supervisord`:

- `supervisorctl status`: check the status of all programs.
- `supervisorctl start program_name`: start one program.
- `supervisorctl stop program_name`: stop one program.

The official documentation covers the rest, including event listeners and process groups, in more detail than a single post can.
