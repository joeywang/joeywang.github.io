# Claude Code Automation for joeywang.github.io

This directory contains skills, agents, and hooks for automated blog workflow.

## 📁 Directory Structure

```
.claude/
├── agents/
│   └── content-reviewer.md          # Quality review agent
├── skills/
│   ├── blog-workflow/
│   │   └── SKILL.md                 # Full automated workflow
│   ├── blog-idea/
│   │   └── SKILL.md                 # Quick idea capture
│   ├── new-blog-post/
│   │   └── SKILL.md                 # Manual post template
│   └── generate-social-post/
│       └── SKILL.md                 # Social media generation
├── settings.json                     # Hooks (team-wide)
├── settings.local.json              # Permissions (local, not committed)
└── README.md                        # This file
```

## 🚀 User-Invocable Skills

Skills available in Claude Code with slash commands:

### `/blog-workflow` ⭐ Main Workflow
**Purpose:** Complete end-to-end blog post creation

**Usage:**
```bash
/blog-workflow
```

**You provide (5 min):**
- Topic and your angle
- Personal experience
- Failure stories (optional)
- Specific numbers (optional)
- Gotchas (optional)

**System generates:**
- Humanized blog post
- Quality review
- Twitter post
- LinkedIn post
- Publishing instructions

**See:** `skills/blog-workflow/SKILL.md`

---

### `/blog-idea` 💡 Idea Capture
**Purpose:** Quick capture for blog ideas

**Usage:**
```bash
/blog-idea "Redis timeouts - everyone fixes it wrong"
```

**Saves to:** `_drafts/ideas.md`

**See:** `skills/blog-idea/SKILL.md`

---

### `/generate-social-post` 📱 Social Media
**Purpose:** Generate Twitter/LinkedIn posts for existing article

**Usage:**
```bash
/generate-social-post
```

**Generates:**
- `static/twitter-{slug}.md`
- `static/linkedin-{slug}.md`

**See:** `skills/generate-social-post/SKILL.md`

---

### `/new-blog-post` 📝 Manual Template
**Purpose:** Create blank post with template (for manual writing)

**Usage:**
```bash
/new-blog-post "Post Title"
```

**Generates:**
- `_posts/{date}-{slug}.md` with frontmatter

**See:** `skills/new-blog-post/SKILL.md`

---

## 🤖 Agents

### content-reviewer
**Purpose:** Quality assurance review for blog posts

**Checks:**
- Frontmatter completeness
- Humanized writing style
- Personal stories included
- Code examples valid
- SEO optimization
- Technical accuracy

**Invocation:** Via Claude during post review

**See:** `agents/content-reviewer.md`

---

## ⚡ Hooks

Automatic actions on tool events (configured in `settings.json`):

### PostToolUse Hooks

**blog-post-created-reminder**
- **Triggers:** After creating a file in `_posts/`
- **Action:** Reminds you to run `bundle exec jekyll serve`

### PreToolUse Hooks

**protect-github-workflows**
- **Triggers:** Before editing `.github/workflows/*`
- **Action:** Confirmation prompt (prevents accidental workflow changes)

**protect-config-files**
- **Triggers:** Before editing `_config.yml`
- **Action:** Confirmation prompt (prevents accidental config changes)

---

## 🔧 Local Settings

### settings.local.json (Not committed)

Permissions for this repository:

```json
{
  "permissions": {
    "allow": [
      "Bash(rtk ls:*)",
      "Bash(rtk git:*)",
      "Bash(bundle:*)",
      "Bash(bundle exec jekyll:*)",
      "Write(_posts/*)",
      "Write(static/*)",
      "Edit(_posts/*)",
      "Edit(static/*)"
    ]
  }
}
```

This allows Claude to:
- Run RTK commands (ls, git)
- Run bundle and Jekyll
- Create/edit posts and social media files

---

## 📖 Documentation

| File | Purpose |
|------|---------|
| `QUICK-START.md` | One-page workflow reference |
| `BLOG-WORKFLOW.md` | Complete workflow guide |
| `CLAUDE-AUTOMATION.md` | All automation features |
| `CLAUDE.md` | Project overview |
| `.claude/README.md` | This file (automation internals) |

---

## 🔄 Workflow Diagram

```
You have an idea
       ↓
   /blog-idea (30 sec) ─────→ Saved for later
       ↓
When ready to write
       ↓
   /blog-workflow (5 min input)
       ↓
   ┌─────────────────────────────┐
   │ System Generates:            │
   │ • Humanized blog post        │
   │ • Quality review             │
   │ • Twitter post               │
   │ • LinkedIn post              │
   │ • Publishing instructions    │
   └─────────────────────────────┘
       ↓
   Preview locally
       ↓
   Edit if needed (optional)
       ↓
   Commit & push
       ↓
   Post to social media
       ↓
   Done! ✨
```

---

## 🎯 Design Principles

### 1. You Focus on Thinking
Skills automate structure, formatting, and style so you can focus on:
- Topic selection
- Your opinions
- Personal experiences
- Lessons learned

### 2. Humanized by Default
The workflow applies humanization rules automatically:
- Personal anecdotes
- Failure stories
- Specific numbers
- Conversational tone
- Emojis in headers

### 3. Quality Checks Built-In
Content reviewer agent catches:
- Missing frontmatter
- AI-sounding language
- Generic content
- Missing personal voice

### 4. Complete Workflow
From idea to published post, nothing manual except:
- Your creative input (5 min)
- Final review (5 min)

---

## 🔨 Customization

### Change Writing Style

Edit `skills/blog-workflow/SKILL.md`:
- Modify "Humanized Template" section
- Adjust "Writing Style Guidelines"
- Change section header formats

### Change Social Media Format

Edit Phase 4 in `skills/blog-workflow/SKILL.md`

### Add/Modify Hooks

Edit `settings.json`:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "name": "your-hook-name",
        "filter": "Write(_posts/.*\\.md)",
        "command": "echo 'Your command here'"
      }
    ]
  }
}
```

### Add New Skills

1. Create directory: `.claude/skills/{skill-name}/`
2. Create `SKILL.md` with frontmatter
3. Test with `/skill-name`
4. Commit with `git add -f .claude/skills/{skill-name}/SKILL.md`

---

## 🆘 Troubleshooting

**Skills not loading?**
→ Restart Claude Code (skills load at session start)

**Permissions denied?**
→ Check `settings.local.json` has correct permissions

**Hooks not firing?**
→ Verify `settings.json` exists and has correct syntax

**Post not humanized enough?**
→ Provide more specific input (failures, numbers, opinions)

---

## 📊 Metrics

**Time savings per post:**
- Before automation: ~2 hours (writing, formatting, social media)
- With automation: ~10 minutes (5 min input + 5 min review)
- **Saved: ~1h 50min per post**

**Quality improvements:**
- Consistent humanized style
- Personal stories always included
- Specific numbers/costs captured
- Social media generated automatically

---

## 🔄 Maintenance

**Review automation periodically:**
```bash
# Check saved ideas
cat _drafts/ideas.md

# Review generated posts
ls -lt _posts/ | head -5

# Check social media files
ls -lt static/ | head -10
```

**Update skills when style evolves:**
```bash
# Edit skill
vim .claude/skills/blog-workflow/SKILL.md

# Test in next session
/blog-workflow
```

---

## ✨ Next Session

After restarting Claude Code, try:

```bash
/blog-workflow
```

Answer the questions (5 min) and watch the automation generate your post!

For more details, see:
- `QUICK-START.md` - One-page reference
- `BLOG-WORKFLOW.md` - Complete guide with examples
