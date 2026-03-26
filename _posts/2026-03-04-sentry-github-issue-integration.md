---
layout: post
title: "Can Sentry Create GitHub Issues? Yes, Here Is How"
date: 2026-03-04
tags: [sentry, github, error-tracking, incident-management]
categories: [Development, DevOps]
description: "How to connect Sentry and GitHub so you can create or link GitHub issues directly from Sentry, plus the fastest fix for the common 'not installed' integration error."
---

# Can Sentry Create GitHub Issues? Yes, Here Is How

Short answer: yes.

If you install the GitHub integration, Sentry can create a new GitHub issue from a Sentry issue, or link an existing GitHub issue to it.

That sounds minor, but it solves a common team problem: errors live in one place, work tracking lives in another, and context gets lost during handoff.

## What the integration gives you

On a Sentry issue page, you can usually use the right sidebar to:

1. Create a new GitHub issue.
2. Link an existing GitHub issue.

In most Sentry UIs this appears in a section named `Linked Issues` or `Issue Tracking`.

## Setup for Sentry SaaS

1. Go to `Settings -> Integrations -> GitHub` in Sentry.
2. Install and authorize the GitHub App.
3. Make sure the repository you need is included in the app installation scope.
4. Open any Sentry issue and find `Linked Issues` or `Issue Tracking`.
5. Select GitHub, then create or link the issue.

## The common failure mode: connected but "not installed"

A frustrating state is when Sentry shows GitHub as connected, but issue creation still fails with a "not installed" or "out of sync" message.

The fix that works most often:

1. Uninstall the Sentry GitHub App from GitHub.
2. Reinstall it from the Sentry integration page.
3. Confirm repository access and permissions again.

This refreshes app permissions and usually clears stale sync state.

## Important distinction: issue tracking vs code mapping

These are related, but not the same:

1. GitHub issue integration lets you create and link GitHub issues from Sentry.
2. Code mapping connects stack frames to files in your repository.

If you see a prompt like "Set up code mapping," that is about source code links and Autofix behavior. It is not required just to create a GitHub issue.

## GitHub.com vs GitHub Enterprise

The flow is the same in principle, but teams on GitHub Enterprise usually hit more permission and installation-scope checks.

If the GitHub option does not appear in Sentry issue tracking:

1. Check that the app is installed for the correct org.
2. Verify the target repo is explicitly included.
3. Confirm your Sentry user has project-level permission to manage linked issues.

## Final takeaway

Sentry can absolutely create GitHub issues, and the setup is straightforward once app scope and permissions are correct.

If your integration looks connected but behaves as if it is not installed, reinstalling the GitHub App and re-checking repo scope is usually the fastest path back to a working flow.

## References

1. [Integrating GitHub with Sentry to Increase Speed to Resolution](https://resources.github.com/actions/integrating-with-sentry/?utm_source=chatgpt.com)
2. [How to Fix "Not Installed" in Sentry GitHub Integration](https://sentry.zendesk.com/hc/en-us/articles/26502626994075-How-to-Fix-Not-Installed-in-Sentry-GitHub-Integration?utm_source=chatgpt.com)
3. [Why do I see a prompt to install the GitHub integration in Autofix?](https://sentry.zendesk.com/hc/en-us/articles/35426915869339-Why-do-I-see-a-prompt-to-install-the-Github-Integration-in-Autofix?utm_source=chatgpt.com)
