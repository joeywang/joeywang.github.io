# Blog Workflow - Focus Only on Thinking

This workflow automates everything except the creative parts (your ideas, opinions, experiences).

## 🎯 You Focus On

- **Topic selection** - What do you want to write about?
- **Your take** - What's your unique angle or opinion?
- **Personal experience** - What happened when you tried this?
- **Failures** - What went wrong and what did you learn?

## 🤖 Automation Handles

- Post structure and formatting
- Humanized writing style
- Quality review
- Social media posts
- Preview and publishing guidance

---

## Quick Start

### When Inspiration Strikes

Capture the idea immediately:

```bash
/blog-idea "Setting up Kubernetes monitoring - everyone overcomplicates it"
```

This saves to `_drafts/ideas.md` for later.

### When Ready to Write

Run the full workflow:

```bash
/blog-workflow
```

**You'll be asked for:**
1. Topic/title
2. Your opinion or angle
3. Your personal experience
4. Any failure stories (optional)
5. Specific numbers/costs (optional)
6. Gotchas or surprises (optional)

**System generates:**
- Complete blog post in humanized style
- Quality review
- Twitter post
- LinkedIn post
- Publishing instructions

**Your total time:** 5 minutes of input

---

## Complete Workflow Diagram

```
Idea Strikes 💡
    ↓
/blog-idea (30 seconds)
    ↓
_drafts/ideas.md (saved for later)
    ↓
When ready to write...
    ↓
/blog-workflow (2-5 min input)
    ↓
System generates:
├── Humanized blog post
├── Quality review
├── Twitter post
└── LinkedIn post
    ↓
Preview locally (bundle exec jekyll serve)
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

## Example: From Idea to Published Post

### Step 1: Capture Idea (30 seconds)

```bash
/blog-idea
```

**You provide:**
> Topic: Debugging production Redis timeout errors
> Take: Official docs tell you to increase timeout, but that's treating symptoms

**Saved to** `_drafts/ideas.md`

### Step 2: Write Post (5 minutes)

**Later that week:**
```bash
/blog-workflow
```

**System asks:**
```
1. Topic: What are you writing about?
```

**You provide:**
```
Topic: Debugging Production Redis Timeouts

Your Take: Everyone tells you to increase the timeout. That's wrong.
I spent 3 days chasing timeouts before realizing our connection pool was too small.

Experience: Production Redis kept timing out during traffic spikes.
Official docs said "increase timeout from 1s to 5s." That helped for a day,
then timeouts came back. Eventually discovered we had 5 connections for
100 threads. Oops.

Failure Story: First fix was increasing timeout. Seemed to work!
Then timeouts returned. Spent $200 on Redis upgrades. Still timed out.
Finally checked connection pool - facepalm moment.

Numbers:
- Original: 5 connections, 100 threads, 15% error rate
- After fix: 50 connections, 0% errors, same Redis instance
- Cost of detour: $200 and 3 days

Gotcha: Connection pool size isn't in the default config.
You have to explicitly set it or you get DEFAULT (5 connections).
```

### Step 3: System Generates (automatic)

**Blog post created:**
`_posts/2026-03-26-debugging-redis-timeouts-production.md`

**Includes:**
- Opening: "I spent $200 and 3 days fixing Redis timeouts the wrong way..."
- Personal story about following official docs
- Failure narrative with costs
- The actual fix (connection pool)
- Section: "The $200 Lesson: Treat Root Cause, Not Symptoms"
- Realistic numbers and metrics
- Gotcha section with config examples

**Social posts created:**
- `static/twitter-debugging-redis-timeouts-production.md`
- `static/linkedin-debugging-redis-timeouts-production.md`

**Quality review:**
```
✅ Humanized writing style
✅ Personal stories included ($200, 3 days)
✅ Specific numbers (5 → 50 connections, 15% → 0% errors)
✅ Failure narrative clear
✅ Technical accuracy verified
```

### Step 4: Preview & Publish (5 minutes)

```bash
bundle exec jekyll serve
# Check http://localhost:4000

# If happy:
git add _posts/2026-03-26-debugging-redis-timeouts-production.md
git add static/twitter-debugging-redis-timeouts-production.md
git add static/linkedin-debugging-redis-timeouts-production.md
git commit -m "Add post: Debugging Redis Timeouts in Production"
git push origin main

# After deploy:
# Post to Twitter and LinkedIn using generated content
```

**Total your time:**
- Idea capture: 30 seconds
- Workflow input: 5 minutes
- Preview & publish: 5 minutes
- **Total: 10 minutes**

**System handled:**
- Post structure
- Humanized writing
- Social media posts
- Quality review
- Publishing instructions

---

## Skills Reference

### `/blog-workflow`
**Purpose:** Complete end-to-end blog post creation

**When to use:** Ready to write a full post

**Input needed:** 5 minutes of your thoughts

**Output:**
- Blog post in humanized style
- Quality review
- Social media posts
- Publishing instructions

### `/blog-idea`
**Purpose:** Quick idea capture

**When to use:** Inspiration strikes but not ready to write

**Input needed:** 30 seconds

**Output:**
- Idea saved to `_drafts/ideas.md`
- Available for later development

### `/generate-social-post`
**Purpose:** Generate social media posts for existing article

**When to use:** Already have a post, need social content

**Input needed:** Specify which post

**Output:**
- Twitter post
- LinkedIn post

### `/new-blog-post`
**Purpose:** Create blank post with template

**When to use:** Want to write manually, just need structure

**Input needed:** Title, description, tags

**Output:**
- Blank post with frontmatter

---

## Tips for Best Results

### Provide Specific Details

**❌ Vague:**
> "I tried setting up Kubernetes and it was hard"

**✅ Specific:**
> "Spent 6 hours on Kubernetes ingress rules, got 503 errors, eventually realized I needed to add health check endpoints"

### Include Numbers

**❌ Generic:**
> "It was expensive"

**✅ Specific:**
> "$200 in AWS bills before I realized I forgot resource limits"

### Share Failures

**❌ Success-only:**
> "Here's how to set up monitoring"

**✅ Include failures:**
> "First I tried Helm charts, wasted 2 days, then discovered kubectl apply works fine"

### Be Opinionated

**❌ Neutral:**
> "There are several ways to do this"

**✅ Opinionated:**
> "Everyone recommends Helm but for simple setups it's overkill"

---

## Workflow Customization

### If You Want Different Style

Edit `.claude/skills/blog-workflow/SKILL.md`:
- Adjust "Humanized Template" section
- Modify "Writing Style Guidelines"
- Change section header formats

### If You Want Different Social Format

Edit the "Phase 4: Generate Social Media Posts" section in blog-workflow skill.

### If You Want Auto-Commit

Add to `.claude/settings.json`:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "name": "auto-commit-blog-posts",
        "filter": "Write(_posts/.*\\.md)",
        "command": "git add _posts/*.md static/*.md && git commit -m 'Add blog post' && git push origin main"
      }
    ]
  }
}
```

---

## FAQ

**Q: Can I edit the generated post?**
Yes! It's markdown. Edit anything before committing.

**Q: What if I don't have a failure story?**
That's fine - skip it. The workflow adapts. But posts with failures are more engaging.

**Q: Can I use this for different post types?**
Yes - the workflow adapts based on your input. Technical tutorial, opinion piece, experience report - all work.

**Q: Do I need to use `/blog-idea` first?**
No - you can go straight to `/blog-workflow` if you're ready to write.

**Q: Can I capture multiple ideas at once?**
Yes - `/blog-idea` appends to `_drafts/ideas.md`. Capture as many as you want.

**Q: What if I want to write manually?**
Use `/new-blog-post` for just the template, then write yourself.

---

## Maintenance

**Review saved ideas periodically:**
```bash
cat _drafts/ideas.md
```

**Check automation is working:**
```bash
# After running /blog-workflow, verify files created:
ls -l _posts/$(date +%Y-%m-%d)-*.md
ls -l static/twitter-*.md static/linkedin-*.md
```

**Update workflow if style drifts:**
Edit `.claude/skills/blog-workflow/SKILL.md`

---

## Next Session Usage

After you restart Claude Code, these skills will be available:

```bash
/blog-idea          # Quick idea capture
/blog-workflow      # Full post creation
/generate-social-post   # Social media for existing post
/new-blog-post      # Manual template creation
```

Start with `/blog-workflow` when you have an idea you want to turn into a post!

---

**Questions or issues?** Check `CLAUDE-AUTOMATION.md` for troubleshooting.
