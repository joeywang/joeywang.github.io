# Claude Code Automation Documentation

This document explains the AI-powered automation setup for the joeywang.github.io blog, including skills, hooks, agents, and MCP servers.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Skills](#skills)
  - [new-blog-post](#new-blog-post)
  - [generate-social-post](#generate-social-post)
- [Hooks](#hooks)
- [Agents](#agents)
- [MCP Servers](#mcp-servers)
- [Workflow Examples](#workflow-examples)
- [Troubleshooting](#troubleshooting)

---

## Overview

The blog uses Claude Code's extensibility features to automate repetitive tasks and ensure quality:

| Feature | Purpose | Invocation |
|---------|---------|------------|
| **CLAUDE.md** | Project context for AI agents | Auto-loaded every session |
| **new-blog-post** | Create blog posts with templates | `/new-blog-post "Title"` |
| **generate-social-post** | Generate Twitter/LinkedIn content | `/generate-social-post` |
| **Hooks** | Automatic reminders & file protection | Triggered automatically |
| **content-reviewer** | Quality assurance reviews | Agent invocation |
| **GitHub MCP** | GitHub integration | `claude mcp add github` |

**Benefits:**
- ⏱️ Saves 10-15 minutes per blog post
- ✅ Ensures consistency across all posts
- 🛡️ Protects critical files from accidental edits
- 📱 Streamlines social media promotion
- 🔍 Maintains quality standards

---

## Installation

### Prerequisites

- Claude Code CLI installed
- Ruby and Jekyll installed (`bundle install`)
- Git repository cloned

### Setup

The automation is already configured in this repository. When you clone and start a Claude Code session, everything loads automatically.

**Optional: Install GitHub MCP Server**

```bash
claude mcp add github
```

This enables GitHub Actions monitoring and PR management from Claude.

---

## Skills

Skills are reusable workflows invoked with slash commands.

### new-blog-post

**Purpose:** Create a new blog post with proper frontmatter and structure.

**Usage:**
```bash
/new-blog-post "Your Post Title"
```

**What it does:**
1. Prompts for:
   - Post title (from command)
   - Brief description (1-2 sentences for SEO)
   - Tags (suggests common ones)

2. Generates filename: `YYYY-MM-DD-slug.md`

3. Creates post with template:
```markdown
---
title: "Your Post Title"
date: 2026-03-26
author: "Joey Wang"
description: "Brief description"
tags: [Tag1, Tag2, Tag3]
---

# Your Post Title

{Introduction}

## 🎯 Overview
## 💡 Key Points
## 🔧 Implementation
## 📊 Best Practices
## ✨ Conclusion
```

**Common tags:**
- Ruby on Rails
- Performance
- Database
- Backend Engineering
- DevOps
- Docker
- Testing
- Security
- PostgreSQL

**File location:** `.claude/skills/new-blog-post/SKILL.md`

---

### generate-social-post

**Purpose:** Generate Twitter and LinkedIn posts for blog articles.

**Usage:**
```bash
/generate-social-post
```

**What it does:**
1. Asks which post to promote (defaults to most recent)
2. Extracts metadata: title, description, key points
3. Generates two files in `static/`:
   - `twitter-{slug}.md` (max 280 chars)
   - `linkedin-{slug}.md` (~500-1000 chars)

**Twitter format:**
```
🚀 Just published: {TITLE}

{DESCRIPTION}

Read more: https://joeywang.github.io/posts/{SLUG}

#{HASHTAGS}
```

**LinkedIn format:**
```
🚀 New article: "{TITLE}"

{EXPANDED DESCRIPTION}

Key takeaways:
• {Point 1}
• {Point 2}
• {Point 3}

Read the full article: https://joeywang.github.io/posts/{SLUG}

#{HASHTAGS}
```

**File location:** `.claude/skills/generate-social-post/SKILL.md`

---

## Hooks

Hooks execute shell commands automatically on tool events.

### PostToolUse Hooks

**blog-post-created-reminder**

Triggers when a new blog post is created in `_posts/`.

**Action:**
```
✅ Blog post created! Preview it locally with:
   bundle exec jekyll serve
   Then visit: http://localhost:4000
```

### PreToolUse Hooks

**protect-github-workflows**

Triggers when editing GitHub Actions workflows.

**Action:**
```
⚠️  WARNING: You are about to edit a GitHub Actions workflow file.
These files control deployment and automation. Please confirm this is intentional.
Continue editing workflow? (y/n)
```

**protect-config-files**

Triggers when editing `_config.yml`.

**Action:**
```
⚠️  WARNING: You are about to edit _config.yml (Jekyll main config).
Changes here affect the entire site build.
Continue? (y/n)
```

**File location:** `.claude/settings.json`

---

## Agents

Agents are specialized AI assistants for specific tasks.

### content-reviewer

**Purpose:** Review blog posts for quality before publishing.

**Usage:**
Invoke the agent and specify the post to review.

**Review checklist:**

1. **Frontmatter Validation**
   - All required fields present (title, date, author, description, tags)
   - Date matches filename
   - Tags use existing conventions

2. **Structure & Organization**
   - Proper heading hierarchy (H1 → H2 → H3)
   - Introduction and conclusion present
   - Logical flow

3. **Writing Style**
   - Emojis in section headers (🎯, 💡, 🔧, 📊, ✨)
   - Professional but approachable tone
   - Real-world examples included

4. **Code Examples**
   - Syntax highlighting specified
   - Code is complete and runnable
   - No security vulnerabilities
   - Proper formatting

5. **Links & References**
   - All links are accessible
   - Internal links use relative paths
   - External links use absolute URLs

6. **SEO & Discoverability**
   - Description is compelling
   - Tags are relevant
   - Title is searchable

7. **Technical Quality**
   - Best practices section included
   - Performance claims backed by data
   - Security considerations mentioned

8. **Content Quality**
   - Provides unique value
   - Actionable insights
   - Key takeaways summarized

**Output format:**
```markdown
# Content Review: {POST_TITLE}

## ✅ Passed Checks
- [List of checks that passed]

## ⚠️ Warnings (Suggestions)
- [Improvements that would enhance quality]

## ❌ Critical Issues (Must Fix)
- [Blocking issues]

## 📊 Overall Assessment
Readiness: [Ready to Publish | Needs Minor Revisions | Needs Major Revisions]
```

**File location:** `.claude/agents/content-reviewer.md`

---

## MCP Servers

MCP (Model Context Protocol) servers extend Claude's capabilities with external integrations.

### GitHub MCP Server

**Purpose:** Direct GitHub integration for repository management.

**Installation:**
```bash
claude mcp add github
```

**Capabilities:**
- Check GitHub Actions workflow status
- View deployment logs
- Monitor PR checks
- Manage issues and pull requests
- View commit history

**Example usage:**
```
"What's the status of my latest deployment?"
"Show me the logs for the failed jekyll build"
"Are there any open PRs?"
```

**Prerequisites:**
- GitHub CLI (`gh`) installed and authenticated
- Repository has GitHub Actions enabled

---

## Workflow Examples

### Creating and Publishing a New Blog Post

**Step 1: Create the post**
```bash
/new-blog-post "Optimizing Rails Database Queries"
```

Claude will prompt for:
- Description: "Learn techniques to optimize database queries in Rails for better performance"
- Tags: Ruby on Rails, Performance, Database, PostgreSQL

**Step 2: Write the content**

Edit the generated file in `_posts/2026-03-26-optimizing-rails-database-queries.md`

**Step 3: Preview locally**
```bash
bundle exec jekyll serve
# Visit http://localhost:4000
```

**Step 4: Review quality**

Invoke the content-reviewer agent to check for issues.

**Step 5: Generate social media posts**
```bash
/generate-social-post
```

Review and edit the generated files in `static/`:
- `twitter-optimizing-rails-database-queries.md`
- `linkedin-optimizing-rails-database-queries.md`

**Step 6: Commit and push**
```bash
git add _posts/2026-03-26-optimizing-rails-database-queries.md
git add static/twitter-optimizing-rails-database-queries.md
git add static/linkedin-optimizing-rails-database-queries.md
git commit -m "Add post: Optimizing Rails Database Queries"
git push origin main
```

**Step 7: Monitor deployment**

If GitHub MCP is installed:
```
"Check the status of my deployment"
```

**Step 8: Post to social media**

Copy content from `static/` files and post to Twitter and LinkedIn.

---

### Quick Post Update

**Scenario:** Fix a typo in an existing post

1. Edit the file directly
2. The `protect-config-files` hook won't trigger (only for _config.yml)
3. Commit and push
4. GitHub Actions automatically rebuilds and deploys

---

### Adding a New Feature to the Blog

**Scenario:** Add a new Jekyll plugin

1. Edit `Gemfile`
2. Run `bundle install`
3. Edit `_config.yml` to configure the plugin
4. The `protect-config-files` hook will prompt for confirmation
5. Test locally with `bundle exec jekyll serve`
6. Commit and push

---

## Troubleshooting

### Skills Not Available

**Problem:** `/new-blog-post` shows "Unknown skill"

**Solution:** Skills are loaded at session start. Restart Claude Code:
```bash
# Exit current session
exit

# Start new session
claude
```

### Hooks Not Firing

**Problem:** No reminder after creating a blog post

**Solution:**
1. Check `.claude/settings.json` exists
2. Verify hook configuration:
```bash
cat .claude/settings.json
```
3. Ensure you're using `Write` tool (hooks trigger on tool use)
4. Restart Claude Code session

### Permission Denied

**Problem:** "Permission denied" when running hooks

**Solution:** Check `.claude/settings.local.json` permissions:
```json
{
  "permissions": {
    "allow": [
      "Bash(bundle:*)",
      "Bash(bundle exec jekyll:*)",
      "Write(_posts/*)",
      "Write(static/*)"
    ]
  }
}
```

### GitHub MCP Not Working

**Problem:** GitHub commands fail

**Solution:**
1. Verify GitHub CLI is installed:
```bash
gh --version
```

2. Authenticate if needed:
```bash
gh auth login
```

3. Check MCP server status:
```bash
claude mcp list
```

4. Reinstall if needed:
```bash
claude mcp remove github
claude mcp add github
```

### Jekyll Serve Fails

**Problem:** `bundle exec jekyll serve` errors

**Solution:**
1. Update dependencies:
```bash
bundle update
```

2. Check Ruby version matches GitHub Actions (3.4):
```bash
ruby --version
```

3. Clear Jekyll cache:
```bash
bundle exec jekyll clean
```

4. Check for port conflicts:
```bash
lsof -i :4000  # Check if port 4000 is in use
```

---

## File Structure

```
.claude/
├── agents/
│   └── content-reviewer.md      # Blog post quality reviewer
├── skills/
│   ├── new-blog-post/
│   │   └── SKILL.md             # Blog post creation skill
│   └── generate-social-post/
│       └── SKILL.md             # Social media generation skill
├── settings.json                # Hooks (team-wide, committed)
└── settings.local.json          # Permissions (local, not committed)

CLAUDE.md                         # Project context for AI agents
CLAUDE-AUTOMATION.md             # This file
```

---

## Contributing

### Adding a New Skill

1. Create directory: `.claude/skills/{skill-name}/`
2. Create `SKILL.md` with frontmatter:
```yaml
---
name: skill-name
description: Brief description
user-invocable: true
disable-model-invocation: true  # For user-only skills
---
```
3. Document the workflow clearly
4. Test in a new Claude Code session
5. Commit with `git add -f .claude/skills/{skill-name}/SKILL.md`

### Adding a New Hook

1. Edit `.claude/settings.json`
2. Add to `PostToolUse` or `PreToolUse` array
3. Test the hook by triggering the filter condition
4. Commit changes

### Improving an Agent

1. Edit the agent file in `.claude/agents/`
2. Update the checklist or workflow
3. Test with a sample blog post
4. Commit changes

---

## Additional Resources

- [Claude Code Documentation](https://docs.anthropic.com/claude/docs)
- [Jekyll Documentation](https://jekyllrb.com/docs/)
- [Chirpy Theme Documentation](https://chirpy.cotes.page/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

**Last Updated:** 2026-03-26

**Maintained by:** Joey Wang

**Questions?** Open an issue or submit a PR!
