---
layout: post
title: "Running Hermes on a Cloud Machine as a Daily Routine Assistant"
date: 2026-07-18 15:01:00 +0100
author: "Joey Wang"
description: "How I wired Hermes Agent on a remote Linux box into Telegram, Gmail, Calendar, Sentry, GitHub, and a daily morning routine."
tags: [ai, agents, hermes, telegram, github, sentry, automation, personal-os]
categories: [AI, Engineering]
---

# Running Hermes on a Cloud Machine as a Daily Routine Assistant

I have wanted a personal assistant for a long time, but most versions of this idea are disappointing.

A chatbot can talk, but it cannot actually see the day. It does not know that my calendar is packed, that CI failed overnight, or that Sentry is full of Redis errors again.

A script can do one useful thing, but then you end up with ten scripts. One for email. One for calendar. One for GitHub. One for Sentry. They all know a little bit, and none of them know what the others found.

This time I tried a different shape: run Hermes on a remote cloud machine, connect it to Telegram, and let it become the one place that reads the signals I already care about.

Not a magic assistant. More like a small operations desk living in a chat window.

## The setup

The machine is just a remote Linux box. Hermes runs there. Telegram is the front door.

```text
Telegram DM
  -> Hermes gateway on remote Linux
     -> Gmail / Google Calendar
     -> Sentry
     -> GitHub via gh
     -> local cloned repos
     -> scheduled jobs
```

The remote part matters. I do not want my laptop to be responsible for reminders. If I close the lid, reboot, or go out, the routine should still happen.

The rough installation path is simple:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
hermes setup
hermes gateway setup
hermes gateway install
hermes gateway start
```

Once Telegram is connected, I can message the agent from my phone. That changes the feel of it. I am not opening another AI product. I am messaging my own remote agent.

## Why Telegram is a good control plane

Telegram is not fancy infrastructure, but it works well for this.

A morning briefing arrives as a normal message. If something looks wrong, I reply. If I want to send a test email, check GitHub, or ask why a CI run failed, I can do it without SSHing into the server.

A dashboard asks me to remember to look at it. A Telegram message finds me.

That makes it a good place for:

- morning routine summaries
- important email reminders
- CI and Sentry alerts
- quick triage when I am away from my laptop
- small commands that do not deserve a full terminal session

## Google access: work and personal, separated

The first useful integration was Google Calendar and Gmail.

I connected my work Google account with Gmail and Calendar access. Hermes can read the calendar, search unread mail, and send email if I explicitly ask it to.

Then I connected my personal Google account separately. I did not want one token replacing the other. The personal token lives under a separate Hermes profile directory, so the daily routine can read both accounts without mixing them up.

```text
~/.hermes/google_token.json
  -> work Google account

~/.hermes/profiles/personal-google/google_token.json
  -> personal Google account
```

The work account has enough permission to send or modify email when I approve it. The personal account is safer: Gmail read-only, plus Calendar. I want reminders from personal email. I do not want an agent casually changing my personal inbox.

Once both accounts were connected, the morning routine could combine the two sides of the day:

```text
Work calendar
Personal calendar
Work email signals
Personal email signals
Suggested plan
Watch-outs
```

That is already more useful than a normal calendar notification. A school event in the personal calendar changes how I should plan work. A GitHub failure in work email changes what the first hour should probably be.

## The first scheduled jobs

Hermes has a cron system, so I set up the first jobs from chat.

The first one was lightweight: send me trending AI topics every morning at 9am UK time.

The second one became the actual assistant:

```text
Daily combined personal routine briefing
Runs: 9:00am UK time
Delivery: Telegram
Sources: work calendar, personal calendar, work Gmail, personal Gmail, Sentry, GitHub
```

The third job checks for important email twice a day. Not all unread email. That would just recreate the inbox in Telegram, which is the opposite of useful.

The job is supposed to look for things that are probably actionable:

- security alerts
- CI failures
- property emails
- appointments
- billing
- school or family messages
- direct work requests

The difference between "unread email digest" and "important email reminder" is the whole point. If the assistant becomes another inbox, it has failed.

## Adding Sentry

After email and calendar, Sentry was the obvious next source.

For work, I gave Hermes a Sentry token and a small list of projects:

```text
org: reallyenglish
projects: rex, turtle, n2r, wfb
```

The token lives in the Hermes `.env` file on the remote machine. It does not belong in prompts, posts, or command history.

A useful Sentry section is not a dump of every issue. It should answer a few questions:

- Is anything new or regressed?
- Is an issue suddenly noisy?
- Does this look production-impacting?
- Is there something I should look at before normal work?

The first test query made the value obvious. There were real unresolved issues across the projects: mail delivery errors, Redis connection errors, Rails exceptions, AI API 403s. Some may be old noise, but seeing them next to calendar and GitHub gives me a better sense of what kind of day I am walking into.

## GitHub via gh

GitHub was already configured on the machine with the `gh` CLI, so Hermes could use it directly.

```bash
gh auth status
gh repo view reallyenglish-global/rex
gh search prs --owner reallyenglish-global --author @me --state open
gh search prs --owner reallyenglish-global --review-requested @me --state open
gh search issues --owner reallyenglish-global --assignee @me --state open
```

The daily job now checks the repos I care about most:

```text
reallyenglish-global/rex
reallyenglish-global/n2r
reallyenglish-global/turtle
reallyenglish-global/wfb
```

It looks for:

- my open PRs
- review requests
- issues assigned to me
- recent failed CI runs
- stale PRs that probably need a decision

This is where the assistant starts to feel less like a calendar bot and more like a small engineering cockpit.

GitHub tells me what I said I was doing. Sentry tells me what production is complaining about. Email tells me what humans are asking for. Calendar tells me how much time I actually have.

Those sources are much more useful together than apart.

## Local repos on the same machine

All my work codebases are cloned under:

```text
/mnt/data/re/
```

That means Hermes can move from triage into investigation.

If the morning briefing says `rex` CI failed, I can reply:

```text
Look at the failed rex CI run and inspect the code locally.
```

Hermes can use GitHub to find the failing run, then use the local clone to search files, run tests, inspect history, and propose a fix. If I want, it can create a branch and open a PR.

That is the bit I care about most. A reminder is nice. A reminder that can turn into a debugging session is much better.

## The safety line

Giving an agent access to email, calendar, GitHub, and Sentry should make you a little nervous. It makes me nervous too.

So the rule is simple: read by default, ask before side effects.

Hermes can read and summarize automatically. It should not do these without explicit approval:

- send an email
- archive or label mail
- create or delete calendar events
- resolve or assign Sentry issues
- comment on GitHub issues or PRs
- close issues
- merge PRs
- push code

I tested email sending once, from my work Gmail to my personal Gmail. It worked. But that is not the interesting part. The interesting part is that sending stays an explicit action, not something hidden inside an automation.

## What the morning message should look like

The target is not a beautiful report. I want one message that reduces morning context switching.

Something like this:

```text
Morning Routine — Monday, 20 July

Work calendar
- 10:00 Standup
- 12:00 Sprint planning, prep the tracking sheet

Personal calendar
- 18:30 Family event

Email signals
- Work: GitHub CI failed in rex
- Personal: property email needs a look

Sentry signals
- rex: mail delivery error, high frequency
- n2r: Redis connection timeout

GitHub signals
- rex CI failed on main
- turtle PR #1036 is still open

Suggested plan
- 09:00 triage email and CI
- 10:00 meeting
- 11:00 investigate rex failure
- 14:00 deep work

Watch-outs
- Leave enough time before the evening family event
```

The content matters more than the format. Tell me what deserves attention. Hide the noise.

## What worked better than expected

The setup worked best because it was incremental.

I did not need to design the perfect personal OS in one go. I connected one thing, tested it, then added the next:

1. Telegram
2. daily AI trends
3. Google Calendar and Gmail
4. personal Google account
5. important email reminders
6. Sentry
7. GitHub
8. local codebase paths

Each step made the assistant slightly more useful. No big migration. No grand architecture.

The other nice surprise is that scheduled jobs feel conversational in Telegram. A cron result is not just a log line. It is a message I can reply to.

## What I would improve next

Sentry and GitHub should probably get real-time alert jobs, not just morning summaries. If CI fails on `main`, I do not want to wait until 9am tomorrow. Same for a Sentry spike.

The briefing also needs tuning. The hard part is not fetching data. It is ranking it. Ten unread emails, ten Sentry issues, and ten open PRs can easily become noise again.

The next thing I want is tighter links from signals to code. If Sentry shows a Rails exception, the assistant should pull the stack trace, find the matching file under `/mnt/data/re/`, and suggest the first place to inspect.

That is where this starts to get interesting. Not just "you have an alert," but "this alert probably maps to this code path."

## Final thoughts

This setup is not futuristic in the flashy sense. It is plumbing: OAuth tokens, API calls, cron jobs, Telegram messages, local repos.

But good plumbing changes behavior.

I now have one remote agent that can tell me what my day looks like, what broke overnight, which emails matter, which PRs are stale, and where the code lives if I want to fix something.

That is enough to be useful. More importantly, it is something I can keep extending.
