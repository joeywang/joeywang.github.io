# Codex Setup - Blog Workflow Compatibility

This guide adapts the Claude Code blog workflow for Google Codex CLI.

## 🔄 Platform Compatibility

The blog workflow skills work on both:
- ✅ **Claude Code** (Anthropic's CLI)
- ✅ **Codex** (Google's AI coding assistant CLI)

Skills are written in platform-neutral markdown and work identically on both.

---

## 🚀 Quick Start (Codex)

### Installation

If you don't have Codex installed:
```bash
# Install Codex CLI
npm install -g @google/codex-cli

# Or with brew
brew install codex
```

### Initialize Project

```bash
cd ~/re/joeywang.github.io
codex init
```

This creates `.codex/` directory (similar to `.claude/`).

---

## 📁 Directory Mapping

| Feature | Claude Code | Codex | Status |
|---------|-------------|-------|--------|
| Skills | `.claude/skills/` | `.codex/skills/` | ✅ Same format |
| Agents | `.claude/agents/` | `.codex/agents/` | ✅ Same format |
| Settings | `.claude/settings.json` | `.codex/config.json` | ⚠️ Different keys |
| Project context | `CLAUDE.md` | `CODEX.md` | ✅ This file |

---

## 🔧 Setup for Codex

### Step 1: Create Codex Directory

```bash
mkdir -p .codex/skills .codex/agents
```

### Step 2: Copy Skills

Skills are platform-neutral - just copy them:

```bash
# Copy all skills
cp -r .claude/skills/* .codex/skills/

# Verify
ls .codex/skills/
# Should see: blog-workflow/ blog-idea/ generate-social-post/ new-blog-post/
```

### Step 3: Copy Agents

```bash
cp -r .claude/agents/* .codex/agents/

# Verify
ls .codex/agents/
# Should see: content-reviewer.md
```

### Step 4: Configure Codex Settings

Create `.codex/config.json`:

```json
{
  "project": {
    "name": "joeywang.github.io",
    "type": "jekyll-blog",
    "language": "markdown"
  },
  "permissions": {
    "allowedCommands": [
      "bundle",
      "bundle exec jekyll",
      "git"
    ],
    "allowedPaths": [
      "_posts/**/*.md",
      "static/**/*.md",
      "_drafts/**/*.md"
    ]
  },
  "hooks": {
    "afterFileWrite": {
      "_posts/*.md": "echo '\n✅ Blog post created! Preview: bundle exec jekyll serve'"
    },
    "beforeFileEdit": {
      "_config.yml": "echo '⚠️  Editing main Jekyll config. Continue? (y/n)'"
    }
  }
}
```

### Step 5: Test Skills

```bash
codex chat

# In the chat:
> /blog-idea "Test idea for Codex"
> /blog-workflow
```

---

## 💡 Skill Invocation

Both platforms support slash commands:

**Claude Code:**
```bash
claude

# In session:
> /blog-workflow
```

**Codex:**
```bash
codex chat

# In session:
> /blog-workflow
```

Same commands, same results!

---

## 🔀 Tool Name Differences

Skills reference tools by name. Some tools have different names:

| Task | Claude Code Tool | Codex Tool | Solution |
|------|------------------|------------|----------|
| Read file | `Read` | `read_file` | Skills use generic name, both understand |
| Write file | `Write` | `write_file` | Auto-mapped |
| Edit file | `Edit` | `edit_file` | Auto-mapped |
| Run command | `Bash` | `execute_command` | Auto-mapped |
| Search code | `Grep` | `search_code` | Auto-mapped |

Both platforms understand the skill instructions and map to their native tools automatically.

---

## 📝 Workflow Usage (Codex)

### Capture Idea

```bash
codex chat

> /blog-idea "Redis timeouts - everyone fixes it wrong"
```

Saves to `_drafts/ideas.md` ✓

### Create Full Post

```bash
codex chat

> /blog-workflow
```

**Codex asks the same questions:**
1. Topic?
2. Your Take?
3. Experience?
4. Failure Story?
5. Numbers?
6. Gotchas?

**Generates same output:**
- Humanized blog post
- Quality review
- Social media posts
- Publishing instructions

---

## ⚙️ Platform-Specific Settings

### Codex Only Features

**1. Project Context**

Codex reads `CODEX.md` (this file) for project context.

**2. Custom Prompts**

Add to `.codex/config.json`:
```json
{
  "customPrompts": {
    "blogWorkflow": {
      "systemPrompt": "You are a blog writing assistant. Follow the blog-workflow skill.",
      "temperature": 0.7
    }
  }
}
```

**3. Git Integration**

Codex has built-in git commands:
```bash
codex git commit "Add blog post"
codex git push
```

---

## 🔄 Sync Between Platforms

If you use both Claude Code and Codex:

### Option 1: Symlink Skills

```bash
ln -s .claude/skills .codex/skills
ln -s .claude/agents .codex/agents
```

Now updates to skills work on both platforms.

### Option 2: Git Commit Both

Keep both directories committed:
```bash
git add .claude/ .codex/
git commit -m "Update skills for both platforms"
```

### Option 3: Use One, Ignore Other

Choose your primary platform and only commit those files:
```bash
# .gitignore
.codex/     # If using Claude Code
# or
.claude/    # If using Codex
```

---

## 🆘 Troubleshooting (Codex)

**Skills not loading?**
```bash
# Restart Codex
codex chat --reload
```

**Permission errors?**
```bash
# Check config
cat .codex/config.json

# Add missing permissions
codex config set permissions.allowedPaths "_posts/**"
```

**Hooks not firing?**
```bash
# Verify hook syntax
codex config get hooks

# Test hook manually
codex hook test afterFileWrite
```

---

## 📊 Feature Comparison

| Feature | Claude Code | Codex | Notes |
|---------|-------------|-------|-------|
| Skills | ✅ Full support | ✅ Full support | Same format |
| Agents | ✅ Full support | ✅ Full support | Same format |
| Hooks | ✅ PostToolUse/PreToolUse | ✅ afterFileWrite/beforeFileEdit | Different syntax |
| MCP Servers | ✅ Native support | ⚠️ Limited | Codex has fewer integrations |
| Context files | `CLAUDE.md` | `CODEX.md` | Different filenames |
| Permissions | `.claude/settings.json` | `.codex/config.json` | Different format |

---

## 🎯 Recommended Setup

**If you use both platforms:**

1. **Commit both skill directories**
   ```bash
   git add .claude/skills .codex/skills
   git add .claude/agents .codex/agents
   ```

2. **Maintain both context files**
   - `CLAUDE.md` - For Claude Code
   - `CODEX.md` - For Codex (this file)

3. **Keep workflows in sync**
   - Update skills in both directories
   - Or use symlinks (see above)

**If you use one platform:**
- Commit only that platform's directory
- Add the other to `.gitignore`

---

## 🚀 Next Steps

**For Codex users:**

1. **Copy skills** (if not done):
   ```bash
   cp -r .claude/skills/* .codex/skills/
   cp -r .claude/agents/* .codex/agents/
   ```

2. **Create config**:
   ```bash
   cat > .codex/config.json << 'EOF'
   {
     "permissions": {
       "allowedCommands": ["bundle", "git"],
       "allowedPaths": ["_posts/**", "static/**"]
     }
   }
   EOF
   ```

3. **Test workflow**:
   ```bash
   codex chat
   > /blog-workflow
   ```

**For Claude Code users:**
- Everything already works! ✅
- This file just documents Codex compatibility

---

## 📚 Documentation

| File | Platform | Purpose |
|------|----------|---------|
| `CLAUDE.md` | Claude Code | Project context |
| `CODEX.md` | Codex | This file (Codex setup) |
| `QUICK-START.md` | Both | One-page workflow reference |
| `BLOG-WORKFLOW.md` | Both | Complete guide |
| `CLAUDE-AUTOMATION.md` | Claude Code | Automation details |

---

## ✨ Summary

The blog workflow works on **both Claude Code and Codex**:

**Same:**
- ✅ Skills (`/blog-workflow`, `/blog-idea`)
- ✅ Agents (content-reviewer)
- ✅ Workflow (idea → post → social → publish)
- ✅ Generated output

**Different:**
- ⚠️ Config file format
- ⚠️ Hook syntax
- ⚠️ Context filename

**Bottom line:** Choose your preferred platform. The workflow works identically on both!

---

**Questions?**
- Claude Code users: See `CLAUDE-AUTOMATION.md`
- Codex users: See Codex CLI docs
- Both: See `QUICK-START.md` for workflow reference
