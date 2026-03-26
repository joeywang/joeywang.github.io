---
name: blog-workflow
description: End-to-end blog post workflow - from idea to published post with social media content
user-invocable: true
disable-model-invocation: false
---

# Blog Workflow - Full Automation

This skill orchestrates the entire blog post creation process. You provide creative input (topic, ideas, opinions), and the system handles structure, writing, review, and publishing.

## Workflow Overview

```
1. Capture Your Input (topic, experiences, opinions)
   ↓
2. Generate Humanized Blog Post
   ↓
3. Auto-Review for Quality
   ↓
4. Generate Social Media Posts
   ↓
5. Preview & Publish Guidance
```

---

## Phase 1: Capture Your Creative Input

Ask the user for:

### Required Information
1. **Topic/Title**: What are you writing about?
2. **Your Take**: What's your opinion or unique angle?
3. **Personal Experience**: Have you tried this? What happened?

### Optional But Valuable
4. **Key Failure Story**: Did something go wrong? What did you learn?
5. **Specific Costs/Numbers**: Any dollar amounts, time spent, metrics?
6. **Gotchas**: What surprised you or wasn't obvious?
7. **Target Audience**: Who is this for? (Rails devs, DevOps engineers, etc.)

### Example Prompt to User
```
Let's write a blog post! I need your creative input:

1. **Topic**: What are you writing about?
   Example: "Setting up Kubernetes monitoring with Prometheus"

2. **Your Take**: What's your opinion or angle?
   Example: "Most guides overcomplicate it. Here's the minimal setup that actually works."

3. **Personal Experience**: Did you try this? What happened?
   Example: "I spent 2 days fighting Helm charts before realizing I could just use kubectl apply"

4. **Failure Story** (optional): What went wrong?
   Example: "First attempt cost me $200 in EC2 because I didn't set resource limits"

5. **Key Numbers** (optional): Any costs, time, metrics to share?
   Example: "Final setup: 30 minutes, $5/month, monitors 50 services"

6. **Gotchas** (optional): What surprised you?
   Example: "Prometheus scrape interval defaults to 1m - set it to 15s for alerts to work"
```

---

## Phase 2: Generate Humanized Blog Post

Using the user's input, create a blog post following this structure:

### File Creation
- **Filename**: `_posts/{TODAY}-{slug}.md`
- **Slug**: Lowercase, hyphenated version of title

### Humanized Template

```markdown
---
layout: post
title: "{USER_TITLE}"
date: {TODAY}
author: "Joey Wang"
tags: [{SUGGESTED_TAGS}]
categories: [{SUGGESTED_CATEGORIES}]
description: "{1-2 SENTENCE DESCRIPTION FROM USER INPUT}"
---

# {TITLE}

{OPENING HOOK - Use their "take" or failure story}

{Personal context - Why did you explore this? What problem were you solving?}

## Why I Even Tried This

{Expand on their motivation - make it relatable}

## The Approach Everyone Recommends (And Why I Didn't Use It)

{If they have an opinion that goes against common advice, lead with that}

## What I Actually Did

{Their actual solution/approach, broken into logical sections with emojis}

### {Step 1 Title} 🚀

{Their experience with this step}

{Code example if applicable}

{What could go wrong - from their gotchas}

### {Step 2 Title} 🔧

{Continue the narrative...}

## The Part That Didn't Go Smoothly

{Their failure story - be specific about costs, time, mistakes}

**What I tried first:**
{The wrong approach}

**Why it failed:**
{The problem}

**What actually worked:**
{The solution}

{If they mentioned specific costs:}
**Cost of learning the hard way:** ${AMOUNT} and {TIME} hours

## What I Wish I'd Known on Day One

{Their gotchas and lessons learned as bullets}

- {Gotcha 1 with explanation}
- {Gotcha 2 with explanation}
- {Gotcha 3 with explanation}

## The Honest Breakdown

{If they provided metrics/numbers, create a reality-check section}

**Time investment:**
- First attempt: {X hours}
- After learning: {Y minutes}

**Cost:**
- During experiments: ${X}
- Production setup: ${Y}/month

**Worth it?** {Honest assessment based on their take}

## What Actually Matters

{Conversational conclusion - circle back to their opinion}

{Realistic expectations - not sales pitch, not doom-and-gloom}

{Final thought - what would they tell a colleague?}

## References

{Any docs, tools, or resources they used}
```

### Writing Style Guidelines

**Apply these humanization rules:**

1. **Opening Hook**
   - Use their failure story or contrarian opinion
   - Make it specific: dates, dollar amounts, hours wasted
   - Example: "Last Tuesday, I spent 6 hours debugging Kubernetes ingress rules before realizing..."

2. **Section Headers**
   - Conversational, not generic
   - Use emojis (🚀, 🔧, 💡, ⚠️, 📊, ✨)
   - Include their perspective
   - Examples:
     - "The Setup That Actually Worked"
     - "Why I Skipped Docker Compose (And Regretted It)"
     - "The $200 Mistake I Made So You Don't Have To"

3. **Personal Voice**
   - Use "I" liberally (I tried, I learned, I spent...)
   - Use "you" to address reader directly
   - Include asides in parentheses
   - Use contractions (don't, won't, it's, you're)
   - Add personality to code comments

4. **Failure Stories**
   - Be specific about what went wrong
   - Include costs (time and money)
   - Show the emotion (frustration, confusion)
   - Always include what you learned
   - Example structure:
     ```
     I thought X would work.

     It didn't. Here's what happened: [specific failure]

     Cost: $X and Y hours.

     The actual fix: [solution]
     ```

5. **Technical Content**
   - Keep code examples but add context
   - Explain why not just what
   - Comment code with personality
   - Show before/after when relevant

6. **Avoid**
   - Robotic structure (Step 1, Step 2...)
   - Corporate speak ("leverage", "utilize", "implement")
   - Passive voice
   - "This article will cover..." openings
   - Perfect clinical descriptions

---

## Phase 3: Auto-Review for Quality

After generating the post, run through this checklist:

### Frontmatter Check
- [ ] Title present and compelling
- [ ] Date matches today
- [ ] Author is "Joey Wang"
- [ ] Description is 1-2 sentences, specific
- [ ] Tags are relevant (3-5 tags)
- [ ] Categories logical

### Humanization Check
- [ ] Opens with hook (failure/opinion, not "In this post...")
- [ ] At least 2 personal anecdotes/war stories
- [ ] Specific numbers (costs, time, metrics)
- [ ] Section headers have personality + emojis
- [ ] Uses "I" and "you" naturally
- [ ] Includes at least one failure story
- [ ] Conversational conclusion (not summary)
- [ ] Code comments have personality

### Content Check
- [ ] Technical accuracy
- [ ] Code examples complete and runnable
- [ ] No obvious typos
- [ ] Links work (if external references)
- [ ] Realistic expectations set
- [ ] Honest about limitations

### Red Flags
- ⚠️ Opening says "In this post, I will..."
- ⚠️ Section headers are generic (Setup, Configuration, Conclusion)
- ⚠️ No personal experience shared
- ⚠️ No failures or mistakes mentioned
- ⚠️ Reads like documentation
- ⚠️ Too perfect (no rough edges)

**If any red flags found:** Revise before proceeding.

**Output to user:**
```
✅ Post created: _posts/{DATE}-{SLUG}.md

Quality Review:
✅ Frontmatter complete
✅ Humanized writing style
✅ Personal stories included
⚠️ Consider adding: [specific suggestions]

Ready for Phase 4 (social media posts)?
```

---

## Phase 4: Generate Social Media Posts

Create both Twitter and LinkedIn posts based on the article.

### Twitter Post

**Format:**
```
{HOOK - their contrarian opinion or failure}

{One-line summary}

Read how I {learned/fixed/discovered} this: {URL}

#{TAG1} #{TAG2} #{TAG3}
```

**Character limit:** Max 280 characters

**Example:**
```
Spent $200 learning Kubernetes monitoring the hard way.

Here's the 30-minute setup that actually works (and costs $5/month).

Read how I went from "why is this so complicated" to "oh, that's it?": https://joeywang.github.io/posts/kubernetes-monitoring-setup

#Kubernetes #DevOps #Monitoring
```

### LinkedIn Post

**Format:**
```
{OPENING - Expand the hook into 2-3 sentences}

{Why it matters - business context}

In this post, I share:
• {Key point 1 from their input}
• {Key point 2}
• {Key point 3}
• {Real costs/numbers if provided}

{Call to action or question}

Read the full breakdown: {URL}

#{TAG1} #{TAG2} #{TAG3} #{TAG4} #{TAG5}
```

**Character range:** 500-1000 characters

**Example:**
```
I spent two days and $200 trying to set up Kubernetes monitoring before I realized I was overcomplicating it.

Every guide I found assumed I wanted enterprise-grade observability with Grafana dashboards, AlertManager, and service mesh integration. I just needed to know if my pods were running.

Here's what I learned about minimal-but-useful Kubernetes monitoring:

• Prometheus alone is enough (no Helm charts needed)
• kubectl apply works better than Helm for simple setups
• Resource limits are critical or you'll get a surprise AWS bill
• 15-second scrape intervals make alerts actually useful

The final setup takes 30 minutes and costs $5/month. It monitors 50 services and has caught 3 production issues already.

What's your approach to Kubernetes monitoring? Over-engineered or minimal?

Read the full story (including the $200 mistake): https://joeywang.github.io/posts/kubernetes-monitoring-setup

#Kubernetes #DevOps #CloudNative #SRE #Monitoring
```

### Save Posts

- `static/twitter-{slug}.md`
- `static/linkedin-{slug}.md`

**Output to user:**
```
✅ Social media posts generated

Twitter (247 chars): static/twitter-{slug}.md
LinkedIn (823 chars): static/linkedin-{slug}.md

Preview both and edit as needed before posting.

Ready for Phase 5 (preview & publish)?
```

---

## Phase 5: Preview & Publish Guidance

Provide clear next steps:

```
✅ Blog post complete!
✅ Quality reviewed
✅ Social media posts ready

Next Steps:

1. Preview locally:
   bundle exec jekyll serve
   Visit: http://localhost:4000/posts/{slug}

2. Review and edit if needed:
   - Check the article reads naturally
   - Verify code examples work
   - Adjust any sections that feel off

3. When satisfied, commit:
   git add _posts/{DATE}-{slug}.md
   git add static/twitter-{slug}.md
   git add static/linkedin-{slug}.md
   git commit -m "Add post: {TITLE}"
   git push origin main

4. After GitHub Pages builds (~2 min), post to social:
   - Copy from static/twitter-{slug}.md
   - Copy from static/linkedin-{slug}.md

5. Monitor engagement:
   - Twitter: Retweet, reply to comments
   - LinkedIn: Respond to comments, engage in discussion

---

Files created:
- _posts/{DATE}-{slug}.md (main article)
- static/twitter-{slug}.md (Twitter post)
- static/linkedin-{slug}.md (LinkedIn post)

Total time: ~5 minutes of your input + automated generation
```

---

## Complete Example Run

**User invocation:**
```
/blog-workflow
```

**System prompt 1:**
```
Let's write a blog post! I need your creative input:

1. Topic: What are you writing about?
2. Your Take: What's your opinion or unique angle?
3. Personal Experience: Did you try this? What happened?
4. Failure Story (optional): What went wrong?
5. Key Numbers (optional): Any costs, time, metrics?
6. Gotchas (optional): What surprised you?
```

**User provides:**
```
1. Topic: "Setting up Sentry error tracking for a Rails app"
2. Take: "The official docs skip the most important part - what to actually do when you get 1000 errors"
3. Experience: "Added Sentry, immediately got flooded with 1000 errors, spent day triaging noise"
4. Failure: "Turned it off after 2 hours because alerts were useless"
5. Numbers: "1000 errors/day, 99% were known issues. Took 3 hours to configure useful alerts"
6. Gotcha: "You have to set up error grouping BEFORE turning on alerts or you'll get paged for CSS missing warnings"
```

**System generates:**
- Humanized blog post with their experiences woven in
- Quality review catches any issues
- Twitter post highlighting the "1000 errors" problem
- LinkedIn post expanding on triage workflow
- Clear next steps for preview and publish

**Total user effort:** 2 minutes of input

---

## Success Criteria

This workflow is successful when:

✅ User only spends 2-5 minutes providing creative input
✅ Generated post sounds like them (personal, authentic)
✅ Post includes specific stories and numbers they provided
✅ Social posts capture the hook and key points
✅ No manual formatting or structure decisions needed
✅ Quality review catches obvious issues
✅ Clear path from idea to published post

## Notes

- This skill can invoke the content-reviewer agent for deeper review
- The humanized template should be adapted based on article length/complexity
- Social posts should match the tone of the article
- Always include their specific numbers and stories - that's what makes it authentic
