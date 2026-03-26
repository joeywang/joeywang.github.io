# Quick Start - Blog Workflow

One-page reference for the automated blog workflow.

## 📝 Creating a Blog Post (2 Ways)

### Option 1: Automated Workflow (Recommended)

**When you have 5 minutes to share your thoughts:**

```bash
/blog-workflow
```

**You'll be asked 6 questions:**
1. **Topic** - What are you writing about?
2. **Your Take** - What's your unique angle or opinion?
3. **Experience** - What happened when you tried this?
4. **Failure** (optional) - What went wrong?
5. **Numbers** (optional) - Any costs, time, metrics?
6. **Gotchas** (optional) - What surprised you?

**System generates:**
- ✅ Complete blog post (humanized style)
- ✅ Quality review
- ✅ Twitter post
- ✅ LinkedIn post
- ✅ Publishing instructions

**Time:** 10 minutes total (5 min input + 5 min review)

---

### Option 2: Quick Idea Capture

**When you just have a thought to save:**

```bash
/blog-idea "Redis timeouts - everyone fixes it wrong"
```

Saves to `_drafts/ideas.md` for later development with `/blog-workflow`.

---

## 💡 Example Workflow Input

```
/blog-workflow

Q1: Topic?
A: Debugging Redis timeouts in production

Q2: Your Take?
A: Everyone tells you to increase timeout. That's treating symptoms, not root cause.

Q3: Experience?
A: Production Redis kept timing out during traffic spikes. Official docs said
   "increase timeout from 1s to 5s." That helped for a day, then timeouts came back.
   Eventually discovered our connection pool was too small (5 connections for 100 threads).

Q4: Failure Story?
A: First fix was increasing timeout - seemed to work! Then timeouts returned.
   Spent $200 upgrading Redis instances. Still timed out. Finally checked
   connection pool configuration. Facepalm moment.

Q5: Numbers?
A: Original: 5 connections, 100 threads, 15% error rate
   After fix: 50 connections, 0% errors, same Redis instance
   Cost of wrong detour: $200 and 3 days

Q6: Gotchas?
A: Connection pool size isn't in the default Rails config. You have to
   explicitly set it in redis.rb or you get DEFAULT (5 connections).
   Nobody mentions this in timeout debugging guides.
```

**System generates complete post with:**
- Opening: "I spent $200 and 3 days fixing Redis timeouts the wrong way..."
- Your failure story woven throughout
- Specific numbers and metrics
- Technical solution with code examples
- "What I Wish I'd Known" section with your gotchas
- Conversational conclusion

---

## 📋 After Generation

**1. Preview locally:**
```bash
bundle exec jekyll serve
# Visit: http://localhost:4000/posts/{slug}/
```

**2. Review files:**
- `_posts/2026-03-26-debugging-redis-timeouts-production.md` (main post)
- `static/twitter-debugging-redis-timeouts-production.md` (Twitter)
- `static/linkedin-debugging-redis-timeouts-production.md` (LinkedIn)

**3. Edit if needed** (optional - usually 90% ready)

**4. Commit and push:**
```bash
git add _posts/2026-03-26-*.md static/*.md
git commit -m "Add post: Debugging Redis Timeouts in Production"
git push origin main
```

**5. Post to social media** (after GitHub Pages builds ~2 min)
- Copy from `static/twitter-*.md`
- Copy from `static/linkedin-*.md`

---

## 🎯 Tips for Best Results

### Be Specific

**❌ Vague:**
> "I tried Kubernetes and it was hard"

**✅ Specific:**
> "Spent 6 hours debugging Kubernetes ingress, got 503 errors, eventually realized I needed health check endpoints"

### Include Real Numbers

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
> "There are several approaches"

**✅ Opinionated:**
> "Everyone recommends Helm but for simple setups it's overkill"

---

## 📚 Full Documentation

- **BLOG-WORKFLOW.md** - Complete workflow guide with examples
- **CLAUDE-AUTOMATION.md** - All automation features and troubleshooting
- **CLAUDE.md** - Project overview and quick commands

---

## 🆘 Troubleshooting

**Skills not available?**
→ Restart Claude Code session (skills load at startup)

**Workflow not asking questions?**
→ Make sure you're using `/blog-workflow` (with slash)

**Post doesn't sound like me?**
→ Provide more specific details in your answers (failures, numbers, opinions)

**Social posts too long?**
→ Edit the generated files in `static/` before posting

**Need help?**
→ Ask Claude: "How does the blog workflow work?"

---

## ⚡ Quick Reference

| Command | Purpose | Time |
|---------|---------|------|
| `/blog-idea` | Save idea for later | 30 sec |
| `/blog-workflow` | Create full post | 5 min input |
| `/generate-social-post` | Social media for existing post | 2 min |
| `/new-blog-post` | Manual post template | 1 min |

**Next session:** Start with `/blog-workflow` when you have a topic!
