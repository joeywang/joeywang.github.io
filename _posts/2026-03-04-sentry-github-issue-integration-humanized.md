---
layout: post
title: "How I Finally Got Sentry to Create GitHub Issues (After 3 Hours of Clicking Around)"
date: 2026-03-04
author: "Joey Wang"
tags: [sentry, github, error-tracking, incident-management]
categories: [Development, DevOps]
description: "The Sentry-GitHub integration seems simple until it doesn't work. Here's what I learned debugging 'connected but not installed' errors and why this integration actually matters for your team."
---

# How I Finally Got Sentry to Create GitHub Issues (After 3 Hours of Clicking Around)

Last Wednesday, I spent three hours trying to get Sentry to create GitHub issues. The integration page showed a green checkmark. GitHub confirmed the app was installed. Everything looked perfect.

Then I clicked "Create issue" and got: **"GitHub integration not installed."**

What?!

If you're here because you're seeing the same error, I feel you. Here's what actually worked.

## Why I Even Care About This

Picture this: Your payment service throws a null pointer exception at 2am. Sentry catches it. You wake up, see the alert, acknowledge it, and think "I'll deal with this after coffee."

By Thursday afternoon, you've forgotten half the context. Was it a staging error or production? Which user triggered it? What was the request payload? Now you're trying to reproduce an error you only half-remember, and the only evidence is buried somewhere in Sentry's UI.

That's the problem this integration solves. One click in Sentry, and boom - GitHub issue created with the complete error context, stack trace, user details, everything. No copy-paste archaeology required.

For a team juggling Sentry alerts and GitHub project boards, this is genuinely useful. When it works.

## What "Connected" Actually Means (Spoiler: Not What You Think)

Here's what confused me for way too long:

Sentry has **two different states** that both look like success:

1. **GitHub App is installed** - This means the OAuth dance worked and Sentry can theoretically talk to GitHub.
2. **Integration is working** - This means Sentry can actually create issues in your specific repository.

You can have #1 without #2. That's the "connected but not installed" trap I fell into.

## The Setup That Should Work (But Probably Won't on First Try)

The official flow goes like this:

1. In Sentry, go to **Settings → Integrations → GitHub**
2. Click "Install" and authorize the GitHub App
3. Select which repositories Sentry can access
4. Open any Sentry issue and look for "Linked Issues" in the sidebar
5. Click "Link GitHub Issue" → "Create new issue"

When I followed these steps, I got to step 5 and hit a wall. The GitHub option was grayed out with a helpful message: "Integration not installed for this project."

But I just installed it! Three times! I checked the settings page! Green checkmark!

## The Fix That Actually Worked

After clicking through every settings page twice, here's what finally fixed it:

**Go to GitHub (not Sentry) and completely uninstall the Sentry app.**

Then go back to Sentry and reinstall it fresh.

Why does this work? I have no idea. My best guess is that the GitHub App and Sentry's internal state can get out of sync, especially if you:

- Installed the app before creating the Sentry project
- Changed repository permissions after installation
- Have multiple GitHub organizations
- Sneezed at the wrong moment during OAuth

The nuclear option (uninstall + reinstall) forces both sides to agree on what "installed" means.

## The Gotcha I Wish Someone Had Told Me

When you reinstall the GitHub App, you have to **explicitly select the repository** where you want issues created.

The default is "All repositories" which sounds like it should work, but it doesn't always sync correctly. I spent 20 minutes debugging this before I realized the target repo wasn't actually in the app's scope.

So when you reinstall:
1. Don't use "All repositories"
2. Explicitly select each repo by name
3. Hit save
4. Wait 30 seconds for sync
5. Refresh your Sentry issue page
6. Try again

That's what finally made the "Create issue" button work for me.

## Code Mapping vs Issue Tracking (Don't Get Confused)

While I was debugging this, Sentry kept prompting me to "Set up code mapping" and I thought that was blocking issue creation. It's not.

Two separate features:

**Issue Tracking** (what we're talking about here):
- Creates/links GitHub issues from Sentry errors
- Requires GitHub App with repo access
- That's it

**Code Mapping** (different thing):
- Links stack trace lines to actual source files in GitHub
- Powers Sentry's Autofix feature
- Nice to have, but not required for basic issue creation

You can create GitHub issues without code mapping. You just won't get the fancy "jump to source" links in stack traces.

## GitHub Enterprise (More Permissions, More Problems)

If you're on GitHub Enterprise, the same fix applies, but you'll hit more permission prompts.

Things I had to check:
- App installed for the correct GitHub org (not my personal account)
- Target repo explicitly included in app scope
- My Sentry user has project-level permission to manage integrations
- GitHub Enterprise URL is configured correctly in Sentry (obvious, but I missed it once)

The reinstall trick still works. The permission surface is just bigger.

## What I Actually Use This For

Now that it's working, here's my workflow:

**Morning standup:**
1. Check Sentry for overnight errors
2. For anything that needs investigation, click "Create GitHub issue"
3. Issue gets auto-tagged with `sentry-error` and assigned based on code ownership
4. Full context is in the issue body - no manual copy-paste

**During incidents:**
1. Someone reports "checkout is broken"
2. I find the error in Sentry
3. Create GitHub issue with full stack trace
4. Link it in the incident Slack thread
5. Context is preserved even after we fix it

**Code review:**
- See `Fixes sentry-123` in PR descriptions
- Click through to see the original error context
- Actually understand what bug the PR is fixing

That's worth the 3 hours of setup pain.

## The Quick Checklist If You're Stuck

Sentry says "connected" but you can't create issues?

1. **Go to GitHub** → Settings → Applications → Sentry
2. **Uninstall the app completely**
3. **Go back to Sentry** → Settings → Integrations → GitHub
4. **Reinstall** and explicitly select your repositories (don't use "All")
5. **Wait 30 seconds** for sync
6. **Try creating an issue again**

That's fixed it for me every single time.

If it still doesn't work:
- Check that you have write access to the target GitHub repo
- Verify your Sentry user has project permissions
- Make sure the project exists in Sentry (sounds obvious, I know)
- Try a different browser (OAuth state can get weird)

## What Actually Matters

Yes, Sentry can create GitHub issues. The setup takes 5 minutes when everything aligns perfectly.

When it doesn't (and the integration shows "connected" but isn't), don't spend hours clicking through settings like I did. Just uninstall the GitHub App completely, reinstall it from Sentry, and make sure your target repo is explicitly selected.

Now when production breaks at 2am, at least the error context makes it to the morning standup. And I don't have to copy-paste stack traces into GitHub while half-asleep.

Small wins.

## References

1. [Integrating GitHub with Sentry](https://resources.github.com/actions/integrating-with-sentry/) - The official guide that assumes everything works
2. [How to Fix "Not Installed" in Sentry GitHub Integration](https://sentry.zendesk.com/hc/en-us/articles/26502626994075) - Sentry support doc that confirmed I wasn't crazy
3. [GitHub Integration in Autofix](https://sentry.zendesk.com/hc/en-us/articles/35426915869339) - The code mapping thing I initially confused with issue tracking
