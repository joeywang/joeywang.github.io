# LinkedIn post: Sentry + GitHub issue tracking

If your team uses Sentry and GitHub, this one setup saves real time.

You can create a GitHub issue directly from a Sentry issue (or link an existing one), so incident context does not get lost between tools.

What to do:
1. In Sentry, open `Settings -> Integrations -> GitHub`.
2. Install/authorize the GitHub App.
3. Confirm the repo is included in app scope.
4. Open a Sentry issue and use `Linked Issues` / `Issue Tracking`.

Most common problem I see:
Sentry looks connected, but still says GitHub is "not installed".

Fastest fix:
Uninstall the GitHub App in GitHub, reinstall from Sentry, then verify repo permissions again.

Also worth knowing:
Issue creation and code mapping are separate. If Sentry asks for code mapping, that is about stack frame links and Autofix, not basic issue creation.

I wrote up the full walkthrough and troubleshooting notes here:
[add your post URL]

#Sentry #GitHub #DevOps #IncidentManagement #DeveloperExperience
