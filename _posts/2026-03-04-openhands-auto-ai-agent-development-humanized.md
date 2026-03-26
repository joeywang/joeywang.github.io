---
layout: post
title: "I Let an AI Agent Write Code for a Week. Here's What Actually Worked."
date: 2026-03-04
author: "Joey Wang"
tags: [openhands, ai-agent, automation, github-actions, developer-productivity]
categories: [Development, AI]
description: "Most AI coding assistants are good at snippets but terrible at full features. I spent a week testing OpenHands to see if autonomous agents are actually useful. Spoiler: yes, but only if you set them up right."
---

# I Let an AI Agent Write Code for a Week. Here's What Actually Worked.

I'll be honest: I was skeptical.

Every AI coding tool I'd tried was good at autocompleting function names and terrible at actually building features. Great for boilerplate, useless for anything that required understanding context or making architectural decisions.

Then I heard about OpenHands - an AI agent that can supposedly work autonomously: edit files, run tests, fix its own mistakes, iterate on tasks. Not just suggesting code, but actually doing the work.

So I spent a week testing it on real projects. Some attempts were brilliant. Some were expensive disasters. Here's what I learned.

## What OpenHands Actually Does (And What It Doesn't)

First, let's clear up what this thing is.

OpenHands isn't another autocomplete tool. It's more like a junior developer in a sandbox who:
- Can read your entire codebase
- Can edit files and run commands
- Can see test output and fix failures
- Can iterate without you babysitting every step
- Can't (yet) make good architectural decisions
- Can't understand vague requirements

Think of it as someone who's smart and eager but has never seen your codebase before. If you tell them "improve authentication," they'll ask 12 clarifying questions and then probably refactor something you didn't ask them to touch.

But if you say "add email/password login to `src/api/auth.ts`, use the Postgres helper in `src/db/index.ts`, return a JWT on success," they'll get it done while you're in a meeting.

That's the sweet spot.

## My First Attempt (AKA: How I Burned $47 in 30 Minutes)

I started by pointing OpenHands at a GitHub issue and saying "fix this." No local testing. Straight to headless mode with production API keys.

The agent spun up, read the issue, made a plan, started editing files... and then got stuck in a loop trying to install dependencies that were already installed. It retried 47 times before I noticed and killed it.

Cost: $47 in API calls.
Code written: 0 lines.
Lesson learned: **Always start local.**

## Getting It Running (The Right Way This Time)

After that expensive lesson, I did what I should have done first: run it locally.

The recommended install uses `uv` (a fast Python package manager):

```bash
uv tool install openhands --python 3.12
openhands serve
```

This spins up a local web UI on port 3000. You can also mount your current directory:

```bash
openhands serve --mount-cwd
```

Why local first? Three reasons I learned the expensive way:

**1. Your prompts will be terrible at first.** Everyone's are. Testing locally means those mistakes cost cents instead of dollars. I went through 15 prompt iterations on one task before I figured out the right level of specificity.

**2. You need to watch what the agent does.** I thought I could fire-and-forget. Nope. The agent makes assumptions, and you need to catch the wrong ones early. Watching it work locally taught me how to write better prompts.

**3. Sandbox escapes are real.** I once had the agent try to `npm install` in my home directory instead of the project folder. If I hadn't been watching locally, that would have been... interesting.

## The Setup Files I Skipped (And Regretted Skipping)

OpenHands supports a `.openhands/` directory for repository-specific configuration. I thought this was optional.

It's not.

I skipped it on my first real task. The agent:
1. Couldn't find the right dependency manager (tried `pip` in a Node project)
2. Used the wrong code style (tabs instead of spaces)
3. Committed without running tests
4. Broke the build

Then I added `.openhands/setup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail  # fail fast, fail loud

# Be boring and explicit here - future you will thank you
npm ci  # not npm install - we want reproducible builds
npx prisma generate  # regenerate the client
```

And `.openhands/pre-commit.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

npm run lint
npm test -- --bail  # stop on first failure
```

Suddenly the agent knew what to do. Setup became deterministic. Bad commits got blocked before they happened.

**Don't skip the setup files.** I wasted 4 hours debugging issues that a 20-line bash script would have prevented.

## The Prompt That Went Nowhere vs. The One That Worked

Here's a prompt I actually tried that went nowhere:

> "Make the auth better"

The agent asked me 6 clarifying questions, then started refactoring the entire authentication system including parts I didn't ask it to touch. After 20 minutes I had a 400-line diff that:
- Renamed half the functions
- Changed the password hashing algorithm
- Moved files around
- Broke 8 tests

I threw it away and started over.

Here's what worked:

> Add email/password login to `src/api/auth.ts`.
>
> Use the existing Postgres helper in `src/db/index.ts` (it's already imported).
>
> Return JWT on success (use the helper in `src/lib/jwt.ts`).
> Return 401 with `{"error": "Invalid credentials"}` on failure.
>
> Add tests in `tests/auth.test.ts` for:
> - Successful login with valid credentials
> - 401 on wrong password
> - 401 on non-existent user
>
> Success criteria: `npm test` passes and `POST /api/auth/login` returns a token for valid credentials.

The agent nailed it in one try. Tests passed. Code was clean. Done in 12 minutes.

The difference? **I named files, defined exact behavior, and specified what "done" looks like.**

## The Rule I Wish I'd Known on Day One

After a week of testing, here's the pattern that consistently works:

**1. Name the files that need to change**
Not "update the API" - say "edit `src/api/users.ts`"

**2. Define the exact behavior**
Not "handle errors" - say "return 400 for invalid input, 500 for database errors"

**3. Specify "done" with runnable commands**
Not "make sure it works" - say "`npm test` passes and the endpoint returns 200"

**4. Keep tasks small enough for one focused PR**
Not "build user management" - say "add GET /users/:id endpoint"

When I followed this rule, success rate was ~80%. When I got vague, success rate dropped to maybe 20% (and cost more in retries).

## Sandboxing (Or: That Time It Tried to Git Push to Main)

OpenHands runs in Docker by default for isolation. Good.

But you control what it can access. And I learned this the hard way when the agent tried to `git push` directly to main.

I'd mounted my entire home directory with:

```bash
export SANDBOX_VOLUMES=$HOME:/workspace:rw
```

Bad idea. The agent had write access to everything - config files, SSH keys, other projects, my actual git repos.

After that scare, I locked it down:

```bash
openhands serve --mount-cwd  # only current directory
```

Or if you need more control:

```bash
export SANDBOX_VOLUMES=$PWD:/workspace:rw
```

**Principle: Give the agent the minimum writable surface area.** Think of it as running untrusted code, because that's basically what it is.

## When I Moved to Headless Mode (And When I Shouldn't Have)

Once I had a workflow that worked reliably for a specific type of task, I moved it to headless mode for automation.

Basic headless usage:

```bash
openhands --headless -t "Add input validation to user signup form"
```

With structured output (useful for CI):

```bash
openhands --headless --json -t "Fix flaky timeout in payment webhook test" > output.jsonl
```

Here's the catch: **Headless mode runs in auto-approve mode.** No confirmations. No "are you sure?" prompts.

I learned this when I ran a headless task that was too vague. The agent:
1. Made assumptions (wrong ones)
2. Edited 12 files (I'd only expected 2)
3. Committed directly to the branch
4. No way to stop it mid-execution

Now I only use headless for:
- Tasks I've done interactively 3+ times and know work
- Workflows that are fully constrained by tests
- Situations where the blast radius is small (test files, documentation)

For anything new or risky, I stay in interactive mode.

## Connecting It to GitHub Issues (The Actually Useful Part)

Here's where OpenHands gets interesting for teams.

You can set up a GitHub Action that:
1. Watches for issues labeled `fix-me`
2. Spins up OpenHands to attempt a fix
3. Opens a PR with the changes
4. You review and iterate via PR comments

I tested this on our backlog of small bugs. Out of 20 issues:
- 12 got fixed correctly on first try
- 5 needed follow-up prompts via PR comments
- 3 were too vague and went nowhere

60% success rate for automated bug fixing is... actually pretty good? Especially for the backlog items nobody wanted to pick up.

The workflow I settled on:

1. **Triage the issue first** - Make sure it's small and testable
2. **Add acceptance criteria** - What should the fix do? What should still work?
3. **Add file context** - Which files are likely involved?
4. **Label it `fix-me`** - Trigger the GitHub Action
5. **Review the PR like any other contributor** - Don't merge garbage just because a robot made it
6. **Iterate via comments if needed** - The agent can respond to review feedback

This turned "backlog that nobody will ever fix" into "backlog that might actually get fixed."

## The Failures I Didn't Expect

Not everything worked. Here are the failure modes I hit:

### 1. Task Too Large
I asked it to "add user profile editing." The agent:
- Touched 23 files
- Created 4 new database migrations
- Refactored the entire user model
- Added features I didn't ask for
- Burned through $30 in tokens

I stopped it and broke the task into 6 smaller ones. Each succeeded.

**Fix:** If you can't describe "done" in 3 sentences, the task is too big.

### 2. Missing Repository Context
The agent kept using the wrong import style because it couldn't infer our conventions from one file.

**Fix:** I added a `.openhands/CONVENTIONS.md`:
```markdown
# Code Conventions

- Use named imports: `import { User } from './models'`
- Use async/await, not callbacks
- Error responses: `{ error: string, code: string }`
- Test files end in `.test.ts`
```

After that, code style was consistent.

### 3. Over-Trusting Autonomous Runs
I merged a PR that looked perfect. Tests passed. Code was clean.

Then production broke because the agent "fixed" a race condition by adding a sleep(). The tests were too fast to catch it.

**Fix:** Code review is mandatory. Always. Even if the agent wrote it. Especially if the agent wrote it.

### 4. Dependency Hell
The agent tried to upgrade a major version of React to fix a deprecation warning. This broke half the app.

**Fix:** I added to `pre-commit.sh`:
```bash
# Block dependency changes
if git diff --cached package.json | grep -q '"version"'; then
  echo "ERROR: Cannot modify dependencies without review"
  exit 1
fi
```

Now dependency changes require human approval.

## What Actually Works Well

After a week of testing, here's where OpenHands genuinely saved time:

**✅ Small, well-defined features**
"Add a CSV export button to the users table" → Done in 15 minutes, would've taken me an hour

**✅ Test file generation**
"Add tests for the payment webhook" → Generated 12 test cases I wouldn't have thought of

**✅ Repetitive refactoring**
"Rename `userId` to `customerId` across the codebase" → Did it correctly in 3 minutes

**✅ Documentation**
"Add JSDoc comments to all functions in `src/api/`" → Actually read the code and wrote accurate docs

**✅ Backlog cleanup**
Old issues nobody wanted to touch → Agent attempts them, some succeed, team reviews the rest

**❌ Architectural decisions**
"Design the user permissions system" → Just... no.

**❌ Vague requirements**
"Make the app faster" → Endless refactoring with no clear endpoint

**❌ Complex business logic**
"Implement the pricing algorithm" → Got the math wrong, would've been a disaster in production

## The Honest Cost Analysis

**Time saved per week:** ~6 hours
- Automated away: boilerplate, tests, docs, small bugs
- Still required: review, fixes, guidance, prompt refinement

**Money spent:** ~$120/week in API calls
- Most expensive: exploratory tasks and retries
- Cheapest: well-scoped headless runs
- ROI: Positive if you value your time >$20/hour

**Hidden costs:**
- Initial setup: 4 hours learning how to prompt effectively
- Ongoing: ~30 min/day monitoring and adjusting
- Failed experiments: Maybe $100 total

Worth it? For me, yes. But only because I treated it as a tool that needs training, not magic.

## What I'd Tell Someone Starting Today

If you want to try OpenHands, here's the path that would've saved me time and money:

**Week 1: Local experimentation**
- Install it locally (`openhands serve --mount-cwd`)
- Try 10-20 small tasks interactively
- Learn what good prompts look like
- Watch what the agent actually does
- Cost: <$5

**Week 2: Add repository customization**
- Create `.openhands/setup.sh` for reproducible environments
- Create `.openhands/pre-commit.sh` to block bad commits
- Add `CONVENTIONS.md` if your code style is non-obvious
- Cost: 2 hours of setup time

**Week 3: Move to headless for proven workflows**
- Identify tasks you've done 3+ times successfully
- Automate those with headless mode
- Keep everything else interactive
- Cost: ~$20-50 depending on usage

**Week 4: Add GitHub Action automation**
- Set up the `fix-me` label trigger
- Start with low-risk issues (docs, tests, small bugs)
- Require human review for everything
- Cost: Depends on your issue volume

**Don't:**
- Start with headless mode (expensive mistakes)
- Give it vague tasks (wastes time and tokens)
- Skip the setup files (creates inconsistent output)
- Trust output without review (even when tests pass)
- Mount your entire filesystem (security nightmare)

## The Real Question: Is This Actually Useful?

A week ago I thought autonomous coding agents were overhyped.

Now? I use OpenHands almost daily, but not the way I expected.

It's not replacing me. It's not "AI does all the work." It's more like having an eager junior dev who:
- Works fast when you give clear instructions
- Needs guidance on architecture and business logic
- Sometimes surprises you with good ideas
- Sometimes makes boneheaded mistakes
- Gets better as you learn how to work with it

The teams that'll get the most value are the ones who:
1. Have clear coding conventions
2. Write good tests (the agent relies on them)
3. Can write specific, bounded tasks
4. Actually review the output
5. Treat it like a team member who needs training

If that sounds like your team, give it a shot. Start local, keep tasks small, and don't skip the setup files.

If you're looking for magic that turns vague ideas into production code? Keep looking. This isn't that.

But if you want to automate away the boring stuff so you can focus on the interesting problems? This actually works.

## Actually Useful References

1. [OpenHands GitHub Repo](https://github.com/OpenHands/OpenHands) - Start here, read the README
2. [Local Setup Docs](https://docs.openhands.dev/openhands/usage/run-openhands/local-setup) - Follow this exactly
3. [Prompting Best Practices](https://docs.openhands.dev/openhands/usage/tips/prompting-best-practices) - Read this before you waste $50 like I did
4. [Repository Customization](https://docs.openhands.dev/openhands/usage/customization/repository) - The `.openhands/` directory that saves you from chaos
5. [Headless Mode Docs](https://docs.openhands.dev/openhands/usage/cli/headless) - For when you're ready to automate
6. [GitHub Action Setup](https://docs.openhands.dev/openhands/usage/run-openhands/github-action) - Issue-to-PR automation
