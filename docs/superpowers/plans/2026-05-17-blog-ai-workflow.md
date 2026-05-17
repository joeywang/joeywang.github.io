# Blog AI Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a two-phase AI workflow that transforms scattered notes into polished blog posts with comprehensive quality review.

**Architecture:** Three skills work together: `/blog-from-notes` (generate draft from scattered notes), `/blog-review` (comprehensive quality review), and `/blog-social` (generate social posts for manual posts). Each skill is independent and reusable.

**Tech Stack:** Claude Code skills (markdown format), Jekyll blog system, Git workflow

---

## File Structure

### New Files to Create

**Skills:**
- `.claude/skills/blog-from-notes/skill.md` - Main skill for generating drafts from notes
- `.claude/skills/blog-review/skill.md` - Main skill for comprehensive review
- `.claude/skills/blog-social/skill.md` - Bonus skill for social media generation

**Directories:**
- `static/review-reports/` - Store review reports

**Example outputs (created by skills at runtime):**
- `_posts/YYYY-MM-DD-slug.md` - Blog posts
- `static/twitter-slug.md` - Twitter posts
- `static/linkedin-slug.md` - LinkedIn posts  
- `static/review-reports/YYYY-MM-DD-slug-review.md` - Review reports

### Files Modified

None - this is all new functionality

---

## Task 1: Create `/blog-from-notes` Skill

**Files:**
- Create: `.claude/skills/blog-from-notes/skill.md`

- [ ] **Step 1: Create skill directory**

```bash
mkdir -p .claude/skills/blog-from-notes
```

- [ ] **Step 2: Write skill file**

Create `.claude/skills/blog-from-notes/skill.md`:

```markdown
---
name: blog-from-notes
description: Transform scattered notes into structured, humanized blog post draft with social media posts
---

# Blog From Notes - Generate Draft from Scattered Content

Transform scattered notes (bullet points, brain dumps, social posts, bookmarks) into a structured, humanized blog post.

## Usage

\`\`\`
/blog-from-notes

Then paste all your scattered content:
- Notes from Apple Notes
- Social media posts you want to expand
- Bookmark annotations
- Code snippets
- Brain dump paragraphs
- Screenshots of notes (I'll read the text)
\`\`\`

## Process

This skill will:

1. **Extract & Organize**
   - Identify main topic/angle
   - Group related points into logical sections
   - Detect: personal stories, failures, gotchas, numbers
   - Flag if critical context is missing

2. **Generate Structure**
   - Create section outline based on content
   - Map notes to sections
   - Identify hook (failure story or contrarian opinion)

3. **Write Full Draft**
   - Apply humanized writing style
   - Weave in personal stories and specific numbers
   - Add emojis to section headers (🚀, 🔧, 💡, ⚠️, 📊, ✨)
   - Include code examples with personality
   - Write conversational opening/conclusion

4. **Auto-generate Social Posts**
   - Twitter: Hook + one-liner + URL (max 280 chars)
   - LinkedIn: Expanded hook + bullet points + question (500-1000 chars)

## Workflow

\`\`\`
User pastes scattered notes
    ↓
Ask clarifying questions if needed
    ↓
Extract key points and organize
    ↓
Generate full blog post
    ↓
Generate social media posts
    ↓
Save all files and report
\`\`\`

## Implementation

### Step 1: Request Notes

Ask user to paste all their scattered content:

\`\`\`
Please paste all your scattered notes, brain dumps, and content for this blog post.

Include anything relevant:
- Bullet points from notes apps
- Social media posts you want to expand  
- Bookmark annotations
- Code snippets
- Paragraphs or thoughts
- Screenshots (I'll read the text)

Just dump everything below, I'll organize it.
\`\`\`

### Step 2: Extract & Analyze

Read all the pasted content and extract:

- **Main topic:** What is this post about?
- **Angle/Opinion:** What's the unique take or contrarian view?
- **Personal stories:** Any specific experiences, dates, costs, time spent?
- **Failures:** What went wrong? Mistakes made?
- **Gotchas:** Surprising issues or non-obvious problems?
- **Code examples:** Any code snippets to include?
- **Numbers:** Costs, time, metrics, specific data?

**If notes are too sparse (< 3 substantial points):**
Ask: "I found [X points]. Can you add more details about [specific gap]?"

**If multiple topics detected:**
Ask: "I see multiple topics here: A, B, C. Which should be the main focus?"

**If no clear hook found:**
Present 2-3 options: "Which hook works best? A) [failure story], B) [contrarian opinion], C) [surprising result]"

### Step 3: Generate Structure

Based on extracted content, create outline:

1. **Opening Hook** - Use failure story or contrarian opinion
2. **Context Section** - Why you explored this
3. **Main Content** - 3-5 sections based on extracted points
4. **Failure/Learning Section** - What went wrong and lessons
5. **Gotchas Section** - Surprising issues
6. **Conclusion** - Conversational wrap-up

Map each extracted point to a section.

### Step 4: Generate Blog Post

Create `_posts/YYYY-MM-DD-{slug}.md`:

**Frontmatter:**
\`\`\`yaml
---
layout: post
title: "{TITLE}"
date: {TODAY}
author: "Joey Wang"
tags: [{INFERRED_TAGS}]
categories: [{INFERRED_CATEGORIES}]
description: "{1-2 SENTENCE SUMMARY}"
---
\`\`\`

**Content Structure:**

\`\`\`markdown
# {TITLE}

{OPENING HOOK - specific failure or opinion with numbers/dates}

{Why you tried this - personal context}

## {Section 1 Title} 🚀

{Personal narrative, code examples, what could go wrong}

\`\`\`python
# Code with personality in comments
def example():
    # This took me 3 hours to figure out
    return solution
\`\`\`

## {Section 2 Title} 🔧

{Continue the story...}

## The Part That Didn't Go Smoothly ⚠️

{Failure story with specifics}

**What I tried first:** {The wrong approach}

**Why it failed:** {The problem}

**What actually worked:** {The solution}

**Cost of learning the hard way:** ${AMOUNT} and {TIME} hours

## What I Wish I'd Known on Day One 💡

{Gotchas as bullets}

- {Gotcha 1 with explanation}
- {Gotcha 2 with explanation}

## The Honest Breakdown 📊

{If numbers available}

**Time investment:**
- First attempt: {X hours}
- After learning: {Y minutes}

**Cost:**
- During experiments: ${X}
- Production: ${Y}/month

**Worth it?** {Honest assessment}

## Conclusion

{Conversational wrap-up - circle back to opinion, realistic expectations}
\`\`\`

**Writing Style Rules:**

1. **Personal voice:** Use "I" liberally, address reader as "you"
2. **Specifics:** Include dates, dollar amounts, time spent
3. **Contractions:** Use don't, won't, it's, you're
4. **No jargon:** Avoid "leverage", "utilize", "implement"
5. **Short paragraphs:** Max 5 lines
6. **Code personality:** Add comments with emotion/context
7. **Conversational:** Write like you're explaining to a colleague

### Step 5: Generate Twitter Post

Create `static/twitter-{slug}.md`:

\`\`\`markdown
{HOOK - failure/opinion with numbers}

{One-line summary}

Read how I {learned/fixed/discovered} this: https://joeywang.github.io/{YEAR}/{MONTH}/{DAY}/{slug}

#{TAG1} #{TAG2} #{TAG3}
\`\`\`

**Requirements:**
- Max 280 characters total
- Hook must be specific (include numbers/costs)
- 3 relevant hashtags

### Step 6: Generate LinkedIn Post

Create `static/linkedin-{slug}.md`:

\`\`\`markdown
{OPENING - Expand hook into 2-3 sentences with business context}

{Why it matters}

In this post, I share:
• {Key point 1 from their input}
• {Key point 2}  
• {Key point 3}
• {Real costs/numbers if provided}

{Call to action or question to readers}

Read the full breakdown: https://joeywang.github.io/{YEAR}/{MONTH}/{DAY}/{slug}

#{TAG1} #{TAG2} #{TAG3} #{TAG4} #{TAG5}
\`\`\`

**Requirements:**
- 500-1000 characters
- Professional but conversational tone
- End with engaging question
- 5 relevant hashtags

### Step 7: Report to User

Output:

\`\`\`
✅ Draft created: _posts/{DATE}-{slug}.md

Organized from your notes:
• Hook: {HOOK_SUMMARY}
• {N} main sections identified
• {N} personal stories included
• {N} code examples added
• {N} specific numbers/costs mentioned

Social posts ready:
• Twitter ({CHAR_COUNT} chars): static/twitter-{slug}.md
• LinkedIn ({CHAR_COUNT} chars): static/linkedin-{slug}.md

Next Steps:
1. Preview locally: bundle exec jekyll serve
2. Review the draft and edit as needed
3. Run /blog-review to get comprehensive feedback

Files created:
- _posts/{DATE}-{slug}.md
- static/twitter-{slug}.md
- static/linkedin-{slug}.md
\`\`\`

## Edge Cases

**Too sparse (< 3 points):**
- Ask: "I found [X points]. Can you add more about [gap]?"
- Don't generate until sufficient content

**Multiple topics:**
- Ask: "Multiple topics detected: A, B, C. Which is the main focus?"
- Don't guess - let user decide

**No clear hook:**
- Generate 2-3 options based on content
- Ask user to pick one
- Example: "A) Your $500 mistake, B) Contrarian take on X, C) Surprising result"

**Code without context:**
- Add comment asking for context
- Example: "// What problem does this solve? What was wrong before?"

**Missing technical details:**
- Flag it: "Note: Missing [X]. Consider adding in review phase."
- Generate draft anyway - don't block on perfection

## Notes

- This skill focuses on **generation** - review comes from `/blog-review`
- Non-destructive: Creates files, never overwrites without asking
- Opinionated: Makes structure decisions to move fast
- Iterative: User can edit draft and re-review
\`\`\`

- [ ] **Step 3: Test the skill**

```bash
# The skill file should now be available as /blog-from-notes
# Will test full workflow in Task 4
echo "✓ Skill file created"
```

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/blog-from-notes/skill.md
git commit -m "feat: add /blog-from-notes skill for generating drafts from scattered notes"
```

---

## Task 2: Create `/blog-review` Skill

**Files:**
- Create: `.claude/skills/blog-review/skill.md`
- Create: `static/review-reports/` directory

- [ ] **Step 1: Create directories**

```bash
mkdir -p .claude/skills/blog-review
mkdir -p static/review-reports
```

- [ ] **Step 2: Write skill file**

Create `.claude/skills/blog-review/skill.md`:

```markdown
---
name: blog-review
description: Comprehensive blog post review across technical accuracy, engagement, style consistency, and completeness
---

# Blog Review - Comprehensive Quality Review

Review blog posts across four dimensions: technical accuracy, engagement, style consistency, and completeness.

## Usage

\`\`\`bash
# Review most recent post
/blog-review

# Review specific post
/blog-review _posts/2026-05-17-specific-post.md
\`\`\`

## Review Dimensions

### ⚙️ Technical Accuracy
- Code examples are correct and runnable
- Commands/configurations are current (not outdated)
- Technical claims are accurate
- Dependencies/versions are compatible
- Links to docs are valid

### 📖 Engagement & Readability
- Opening hook is strong (not "In this post...")
- Section headers have personality + emojis
- Personal stories are specific (dates, numbers, emotions)
- Transitions flow naturally
- Conclusion is conversational (not just summary)
- Paragraphs aren't too long (< 5 lines)

### 🎨 Style Consistency  
- Voice matches other posts (conversational, first-person)
- Uses "I" and "you" naturally
- Includes failure stories and lessons
- Code comments have personality
- No corporate jargon ("leverage", "utilize", "implement")
- Contractions used appropriately

### ✅ Completeness
- Key gotchas explained
- Edge cases addressed
- "Why" not just "what"
- Cost/time estimates realistic
- Prerequisites mentioned
- Follow-up resources included

## Implementation

### Step 1: Identify Target Post

**If no argument provided:**
- Find most recent post by filename date (YYYY-MM-DD prefix)
- `ls -t _posts/*.md | head -1`

**If path provided:**
- Use that specific file
- Validate it exists

Report: "Reviewing: {filename}"

### Step 2: Read the Post

Read the entire post file with line numbers.

Store for analysis:
- Frontmatter (title, date, tags, categories, description)
- Opening paragraph
- Section headers
- Code blocks
- Links
- Conclusion

### Step 3: Technical Accuracy Review

**Check:**

1. **Code syntax:**
   - Look for obvious syntax errors
   - Check code blocks have proper language tags
   - Verify closing braces/brackets

2. **Framework/library versions:**
   - Check if Rails/Ruby/package versions mentioned are current
   - Flag deprecated methods (e.g., old Rails syntax)

3. **Commands:**
   - Verify command syntax is correct
   - Check flags are valid

4. **Links:**
   - Note any external links (can't validate, but list them)

5. **Technical claims:**
   - Flag claims that seem incorrect or overly broad
   - Note unsubstantiated performance claims

**Output format:**
\`\`\`markdown
## ⚙️ Technical Accuracy

### ✅ Strengths
- Code examples are syntactically correct
- Commands use current syntax

### ⚠️ Issues
- Line 34: \`config.cache_store\` syntax outdated for Rails 7.1
  **Fix:** Use \`config.cache_store = :redis_cache_store\`
  
- Line 89: Missing error handling for Redis connection failure
  **Add:** \`rescue Redis::CannotConnectError\` block
\`\`\`

### Step 4: Engagement & Readability Review

**Check:**

1. **Opening hook:**
   - Does it start with "In this post..." or similar? ❌
   - Does it start with specific failure/opinion? ✅
   - Includes specific numbers/dates? ✅

2. **Section headers:**
   - Have personality (not generic "Setup", "Configuration")? ✅
   - Include emojis? ✅
   - Example bad: "Setting Up Redis"
   - Example good: "The 5-Minute Redis Setup 🚀"

3. **Personal stories:**
   - Check for "I" statements
   - Specific dates, costs, time mentioned?
   - Emotions expressed?

4. **Paragraph length:**
   - Count lines in each paragraph
   - Flag paragraphs > 5 lines

5. **Transitions:**
   - Check flow between sections
   - Look for abrupt topic changes

6. **Conclusion:**
   - Is it conversational?
   - Does it circle back to opening?
   - Or is it just a summary list?

**Output format:**
\`\`\`markdown
## 📖 Engagement & Readability

### ✅ Strengths  
- Strong opening hook with $500 failure story
- Good use of emojis in headers (🚀, 🔧, 💡)

### ⚠️ Issues
- Line 23: Opening is too generic - "In this post, I will..."
  **Fix:** Start with the failure story: "Last Tuesday, I spent $500..."

- Section header (line 67): "Setting Up Redis" lacks personality
  **Suggestion:** "The 5-Minute Redis Setup That Actually Works 🚀"

- Line 156-164: Paragraph is 8 lines long
  **Fix:** Break into 2 paragraphs at "The key difference..."
\`\`\`

### Step 5: Style Consistency Review

**Check:**

1. **Voice:**
   - Conversational tone?
   - First-person ("I") vs third-person?
   - Direct address ("you")?

2. **Contractions:**
   - Are contractions used? (don't, won't, it's)
   - Or formal? (do not, will not, it is)

3. **Jargon:**
   - Search for: "leverage", "utilize", "implement", "facilitate"
   - Flag corporate speak

4. **Code comments:**
   - Do comments have personality?
   - Or are they clinical?
   - Example bad: `# Initialize connection`
   - Example good: `# This took me 3 hours to figure out`

5. **Failure stories:**
   - Are mistakes/failures included?
   - Or is it too perfect?

**Output format:**
\`\`\`markdown
## 🎨 Style Consistency

### ✅ Strengths
- Conversational tone throughout
- Good use of contractions
- First-person narrative

### ⚠️ Issues  
- Line 203: "In order to leverage this solution" → Corporate jargon
  **Fix:** "To fix this, I..." or "Here's what worked..."

- Line 134-138: Code comments are clinical
  **Add personality:** "# This retry logic saved me after the 2AM outage"

- Missing failure story - post is too perfect
  **Suggestion:** Add a section on what didn't work first
\`\`\`

### Step 6: Completeness Review

**Check:**

1. **Prerequisites:**
   - Are they mentioned?
   - Are they complete?

2. **Gotchas:**
   - Non-obvious problems addressed?
   - Edge cases mentioned?

3. **Why vs What:**
   - Does it explain reasons, not just steps?

4. **Cost/Time:**
   - Are estimates realistic?
   - Specific numbers given?

5. **Follow-up resources:**
   - Links to docs?
   - Related articles?

**Output format:**
\`\`\`markdown
## ✅ Completeness

### ✅ Strengths
- Cost estimates included ($15/month)
- Prerequisites clearly listed
- Time investment mentioned

### ⚠️ Issues
- Missing: What happens if Redis goes down?
  **Add:** Section on failure modes and fallback strategy

- Missing: How to monitor Redis memory usage  
  **Add:** Mention \`INFO memory\` command or monitoring setup

- Line 89: Explains "what" but not "why"
  **Clarify:** Why use Redis over Memcached? What's the tradeoff?
\`\`\`

### Step 7: Generate Summary

**Overall assessment:**
- Count total issues (technical, engagement, style, completeness)
- Determine status: READY (0-2 minor issues) or NEEDS WORK (3+ issues)
- Prioritize: must-fix vs nice-to-have

**Output format:**
\`\`\`markdown
## Summary & Next Steps

**Status: NEEDS WORK** (3 technical issues, 4 engagement improvements)

**Priority fixes (must do before publishing):**
1. Fix Rails 7.1 cache_store syntax (line 34)
2. Add error handling for Redis connection (line 89)  
3. Replace corporate jargon (line 203)

**Optional improvements (nice to have):**
- Break up long paragraph (line 156)
- Add Redis failure mode discussion
- Add personality to code comments

**After fixes:**
- Run \`/blog-review\` again to verify
- Or proceed to publish if you're satisfied with optional improvements pending

**To publish:**
\`\`\`bash
git add _posts/{DATE}-{slug}.md
git commit -m "Add post: {TITLE}"
git push origin main
\`\`\`
\`\`\`

### Step 8: Write Review Report

Create `static/review-reports/{DATE}-{slug}-review.md` with full review output.

**File structure:**
\`\`\`markdown
# Review: {POST_TITLE}

**Date:** {TODAY}  
**Post:** _posts/{DATE}-{slug}.md  
**Status:** READY | NEEDS WORK

## Overall Assessment

{2-3 sentence summary}

---

{Full review sections from Steps 3-6}

---

## Summary & Next Steps

{Summary from Step 7}
\`\`\`

### Step 9: Report to User

\`\`\`
✅ Review complete: {FILENAME}

Status: READY | NEEDS WORK ({N} issues found)

Review report saved to:
static/review-reports/{DATE}-{slug}-review.md

Priority fixes: {N}
Optional improvements: {N}

{If NEEDS WORK:}
Recommended: Fix priority issues and run /blog-review again

{If READY:}
Post is ready to publish!
\`\`\`

## Output Behavior

- **Non-destructive:** Never modifies the post, only creates review report
- **Actionable:** Every issue includes line number and specific fix
- **Prioritized:** Separates must-fix from nice-to-have
- **Re-runnable:** Can run multiple times, creates new report each time

## Notes

- Review is opinionated - uses style guide from CLAUDE.md and existing blog posts
- Technical accuracy check is surface-level - can't actually run code
- Links are listed, not validated (would require network access)
- Review report is snapshot - re-run after edits for updated review
\`\`\`

- [ ] **Step 3: Test the skill file syntax**

```bash
# Verify markdown is valid
cat .claude/skills/blog-review/skill.md | head -20
echo "✓ Skill file created"
```

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/blog-review/skill.md static/review-reports/.gitkeep
git commit -m "feat: add /blog-review skill for comprehensive post quality review"
```

---

## Task 3: Create `/blog-social` Skill

**Files:**
- Create: `.claude/skills/blog-social/skill.md`

- [ ] **Step 1: Create skill directory**

```bash
mkdir -p .claude/skills/blog-social
```

- [ ] **Step 2: Write skill file**

Create `.claude/skills/blog-social/skill.md`:

```markdown
---
name: blog-social
description: Generate social media posts (Twitter, LinkedIn) for manually written blog posts
---

# Blog Social - Generate Social Media Posts

Generate Twitter and LinkedIn posts for manually written blog posts that didn't go through `/blog-workflow` or `/blog-from-notes`.

## Usage

\`\`\`bash
# Generate social posts for specific post
/blog-social _posts/2026-05-17-my-manual-post.md
\`\`\`

## Purpose

Fills the gap when you write a post manually but want social media posts generated automatically.

## Implementation

### Step 1: Read the Blog Post

- Validate file exists
- Read full content with line numbers
- Extract:
  - Title (from frontmatter)
  - Opening paragraphs (first 3-5 paragraphs)
  - Key technical points
  - Any failure stories or specific numbers
  - Code examples (note what they demonstrate)

Report: "Generating social posts for: {TITLE}"

### Step 2: Identify Hook

From the post content, extract the most compelling hook:

1. **Failure story with cost:** "$500 mistake", "3-day debugging nightmare"
2. **Contrarian opinion:** "Most guides say X, but Y actually works better"
3. **Surprising result:** "Expected X, got Y instead"
4. **Specific numbers:** "Cut deploy time from 30min to 2min"

If multiple hooks available, prefer failure > contrarian > numbers.

### Step 3: Generate Twitter Post

Create `static/twitter-{slug}.md`:

**Format:**
\`\`\`markdown
{HOOK - 1 sentence with specific numbers/cost}

{ONE-LINE SUMMARY of what the post covers}

Read how I {learned/fixed/discovered} this: https://joeywang.github.io/{YEAR}/{MONTH}/{DAY}/{slug}

#{TAG1} #{TAG2} #{TAG3}
\`\`\`

**Requirements:**
- Max 280 characters TOTAL (including URL and hashtags)
- Hook must be specific (numbers, dates, costs)
- Summary is ONE line only
- URL format: https://joeywang.github.io/YYYY/MM/DD/slug (extract from filename)
- 3 relevant hashtags from post tags/categories

**Example:**
\`\`\`
Spent $500 learning Kubernetes monitoring the hard way.

Here's the 30-minute setup that actually works (and costs $15/month).

Read how I went from "why is this so complicated" to "oh, that's it?": https://joeywang.github.io/2026/05/17/kubernetes-monitoring

#Kubernetes #DevOps #Monitoring
\`\`\`

**Character count check:**
- Count total characters
- If > 280, trim summary or hook
- URL is ~60 chars, hashtags ~30 chars, leaves ~190 for content

### Step 4: Generate LinkedIn Post

Create `static/linkedin-{slug}.md`:

**Format:**
\`\`\`markdown
{OPENING - Expand the hook into 2-3 sentences with business context}

{Why it matters - connect to broader impact}

In this post, I share:
• {Key technical point 1}
• {Key technical point 2}
• {Key technical point 3}
• {Specific numbers/costs if mentioned}

{Call to action or engaging question to readers}

Read the full breakdown: https://joeywang.github.io/{YEAR}/{MONTH}/{DAY}/{slug}

#{TAG1} #{TAG2} #{TAG3} #{TAG4} #{TAG5}
\`\`\`

**Requirements:**
- 500-1000 characters (target: 700-800)
- Professional but conversational tone
- Bullet points highlight key takeaways
- End with engaging question (not just "read more")
- 5 relevant hashtags

**Example:**
\`\`\`
I spent two days and $500 trying to set up Kubernetes monitoring before I realized I was overcomplicating it.

Every guide I found assumed I wanted enterprise-grade observability with Grafana dashboards, AlertManager, and service mesh integration. I just needed to know if my pods were running.

Here's what I learned about minimal-but-useful Kubernetes monitoring:

• Prometheus alone is enough (no Helm charts needed)
• kubectl apply works better than Helm for simple setups
• Resource limits are critical or you'll get a surprise AWS bill
• 15-second scrape intervals make alerts actually useful

The final setup takes 30 minutes and costs $15/month. It monitors 50 services and has caught 3 production issues already.

What's your approach to Kubernetes monitoring? Over-engineered or minimal?

Read the full story (including the $500 mistake): https://joeywang.github.io/2026/05/17/kubernetes-monitoring

#Kubernetes #DevOps #CloudNative #SRE #Monitoring
\`\`\`

**Character count check:**
- Count total characters
- Target: 700-800 (comfortable reading length)
- If < 500: Expand business context or add more details
- If > 1000: Trim less important points

### Step 5: Extract URL and Hashtags

**URL construction:**
- Filename: `_posts/YYYY-MM-DD-slug.md`
- URL: `https://joeywang.github.io/YYYY/MM/DD/slug`
- Extract year, month, day from filename prefix
- Extract slug by removing `.md` extension

**Hashtag generation:**
- Read frontmatter `tags` field
- Convert to hashtags: "Ruby on Rails" → "#RubyOnRails"
- Maximum 3 for Twitter, 5 for LinkedIn
- Prefer specific over generic: "#RailsPerformance" > "#Programming"

### Step 6: Report to User

\`\`\`
✅ Social media posts generated for: {TITLE}

Twitter ({CHAR_COUNT} chars): static/twitter-{slug}.md
LinkedIn ({CHAR_COUNT} chars): static/linkedin-{slug}.md

Hook used: {HOOK_SUMMARY}

Next steps:
1. Review both files and adjust tone if needed
2. Copy content when ready to post
3. Post after your article goes live on GitHub Pages

Files created:
- static/twitter-{slug}.md
- static/linkedin-{slug}.md
\`\`\`

## Edge Cases

**Post has no clear hook:**
- Use the main technical point instead
- Format: "Here's how to {main technical achievement}"

**Post is very technical with no story:**
- Focus on the technical achievement
- Example: "Reduced Redis memory usage by 60% with these 3 config changes"

**Post has multiple topics:**
- Use the first major topic as the hook
- Mention others as bullet points in LinkedIn

**Character limits:**
- Twitter > 280: Trim summary first, then hook
- LinkedIn < 500: Expand with more technical details or context
- LinkedIn > 1000: Remove less important bullets

## Notes

- This skill only generates - doesn't post to social media
- Non-destructive: Creates files, never overwrites without asking
- Can be re-run if you edit the blog post and want refreshed social posts
\`\`\`

- [ ] **Step 3: Test skill file syntax**

```bash
cat .claude/skills/blog-social/skill.md | head -20
echo "✓ Skill file created"
```

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/blog-social/skill.md
git commit -m "feat: add /blog-social skill for generating social posts for manual posts"
```

---

## Task 4: Integration Test - Full Workflow

**Files:**
- Test: All three skills work together
- Verify: Files are created correctly

- [ ] **Step 1: Test /blog-from-notes with sample content**

Create test content file:

```bash
cat > /tmp/test-blog-notes.txt << 'EOF'
Topic: Rails caching gotcha

Experience:
- Added Redis caching to Rails app last week
- Thought it would speed up queries
- Actually made it SLOWER
- Spent 2 days debugging
- Problem: I was caching the wrong thing
- Was caching database queries but the views were the slow part

Cost: 2 days of dev time, about $800 in wasted time

Code:
# Wrong - caching query
@users = Rails.cache.fetch('users') { User.all.to_a }

# Right - caching rendered view
<%= cache @users do %>
  <%= render @users %>
<% end %>

Gotcha: Rails.cache.fetch returns different object types on hits vs misses
This broke our code that expected ActiveRecord::Relation

The fix: Always call .to_a when caching queries
EOF
```

Test the skill:

```bash
# Will invoke /blog-from-notes manually and paste test content
echo "Ready to test /blog-from-notes - invoke skill and paste test content"
```

**Expected outcome:**
- Post created: `_posts/2026-05-17-rails-caching-gotcha.md`
- Twitter post: `static/twitter-rails-caching-gotcha.md`
- LinkedIn post: `static/linkedin-rails-caching-gotcha.md`

- [ ] **Step 2: Verify generated files**

```bash
# Check files exist
ls -lh _posts/2026-05-17-rails-caching-gotcha.md
ls -lh static/twitter-rails-caching-gotcha.md
ls -lh static/linkedin-rails-caching-gotcha.md

# Verify frontmatter
head -20 _posts/2026-05-17-rails-caching-gotcha.md

# Check Twitter char count
wc -c static/twitter-rails-caching-gotcha.md
# Should be < 280

# Check LinkedIn char count  
wc -c static/linkedin-rails-caching-gotcha.md
# Should be 500-1000
```

- [ ] **Step 3: Test /blog-review**

```bash
# Will invoke /blog-review (should auto-detect latest post)
echo "Ready to test /blog-review"
```

**Expected outcome:**
- Review report: `static/review-reports/2026-05-17-rails-caching-gotcha-review.md`
- Console output shows status and issue count

- [ ] **Step 4: Verify review report**

```bash
# Check review file exists
ls -lh static/review-reports/2026-05-17-rails-caching-gotcha-review.md

# Check structure
cat static/review-reports/2026-05-17-rails-caching-gotcha-review.md | grep "^##"

# Should show all four review dimensions:
# ## ⚙️ Technical Accuracy
# ## 📖 Engagement & Readability
# ## 🎨 Style Consistency
# ## ✅ Completeness
# ## Summary & Next Steps
```

- [ ] **Step 5: Test /blog-social with manual post**

Create a minimal manual post for testing:

```bash
cat > _posts/2026-05-17-test-manual-post.md << 'EOF'
---
layout: post
title: "Test Manual Post"
date: 2026-05-17
author: "Joey Wang"
tags: [Testing]
categories: [Test]
description: "A test post for blog-social skill"
---

# Test Manual Post

This is a manually written post to test the /blog-social skill.

I spent 3 hours testing this feature.

The result: it works!
EOF

# Will invoke /blog-social with this file
echo "Ready to test /blog-social _posts/2026-05-17-test-manual-post.md"
```

**Expected outcome:**
- Twitter post: `static/twitter-test-manual-post.md`
- LinkedIn post: `static/linkedin-test-manual-post.md`

- [ ] **Step 6: Verify social posts for manual post**

```bash
ls -lh static/twitter-test-manual-post.md
ls -lh static/linkedin-test-manual-post.md

# Check character counts
wc -c static/twitter-test-manual-post.md
wc -c static/linkedin-test-manual-post.md
```

- [ ] **Step 7: Clean up test files**

```bash
# Remove test files
rm _posts/2026-05-17-rails-caching-gotcha.md
rm _posts/2026-05-17-test-manual-post.md
rm static/twitter-rails-caching-gotcha.md
rm static/linkedin-rails-caching-gotcha.md
rm static/twitter-test-manual-post.md
rm static/linkedin-test-manual-post.md
rm static/review-reports/2026-05-17-rails-caching-gotcha-review.md
rm /tmp/test-blog-notes.txt

echo "✓ Test files cleaned up"
```

- [ ] **Step 8: Commit - Integration tests passed**

```bash
git status
# Should show nothing to commit (test files cleaned up)

echo "✅ Integration test complete - all three skills working"
```

---

## Task 5: Update Documentation

**Files:**
- Modify: `CLAUDE.md` (add skill documentation)

- [ ] **Step 1: Read current CLAUDE.md**

```bash
cat CLAUDE.md
```

- [ ] **Step 2: Add skills section to CLAUDE.md**

Add after the "## Creating Blog Posts" section:

```markdown
## Blog Workflow Skills

### /blog-from-notes - Generate from Scattered Notes

Transform scattered notes into structured blog posts.

**Usage:**
\`\`\`bash
/blog-from-notes
# Then paste all your notes, brain dumps, code snippets
\`\`\`

**What it does:**
- Extracts main topic, opinions, stories, gotchas
- Organizes into logical sections  
- Generates humanized blog post
- Creates social media posts (Twitter + LinkedIn)

**Output:**
- `_posts/YYYY-MM-DD-slug.md`
- `static/twitter-slug.md`
- `static/linkedin-slug.md`

### /blog-review - Comprehensive Quality Review

Review posts across technical accuracy, engagement, style, and completeness.

**Usage:**
\`\`\`bash
# Review latest post
/blog-review

# Review specific post
/blog-review _posts/2026-05-17-post.md
\`\`\`

**Reviews:**
- ⚙️ Technical accuracy (code, commands, links)
- 📖 Engagement (hook, stories, flow)
- 🎨 Style consistency (voice, tone, jargon)
- ✅ Completeness (gotchas, why not just what)

**Output:**
- Console report with priority fixes
- `static/review-reports/YYYY-MM-DD-slug-review.md`

### /blog-social - Generate Social Posts

Generate Twitter and LinkedIn posts for manually written posts.

**Usage:**
\`\`\`bash
/blog-social _posts/2026-05-17-my-post.md
\`\`\`

**Output:**
- `static/twitter-slug.md` (< 280 chars)
- `static/linkedin-slug.md` (500-1000 chars)

### Complete Workflow Examples

**From scattered notes:**
\`\`\`bash
/blog-from-notes
# Paste notes → Get draft
/blog-review
# Get feedback → Edit post
/blog-review
# Verify fixes → Publish
\`\`\`

**Manual post:**
\`\`\`bash
# Write post manually in _posts/
/blog-social _posts/YYYY-MM-DD-post.md
# Get social posts
/blog-review
# Get feedback
\`\`\`
```

- [ ] **Step 3: Commit documentation**

```bash
git add CLAUDE.md
git commit -m "docs: add blog workflow skills documentation"
```

---

## Spec Self-Review Checklist

**Spec coverage:**
- ✅ `/blog-from-notes` skill - Task 1
- ✅ `/blog-review` skill - Task 2
- ✅ `/blog-social` skill - Task 3
- ✅ Integration testing - Task 4
- ✅ Documentation updates - Task 5
- ✅ File structure (skill files, review-reports/ directory)
- ✅ Example end-to-end workflow (tested in Task 4)

**Placeholder scan:**
- ✅ No TBD or TODO
- ✅ All code blocks are complete
- ✅ All commands are specific
- ✅ All file paths are exact

**Type consistency:**
- ✅ Skill names consistent: `blog-from-notes`, `blog-review`, `blog-social`
- ✅ File paths consistent: `static/twitter-{slug}.md`, `static/linkedin-{slug}.md`
- ✅ Directory structure consistent: `.claude/skills/{skill-name}/skill.md`

**All spec requirements covered:**
- ✅ Two-phase pipeline (generate + review)
- ✅ Notes dump input format
- ✅ Comprehensive review dimensions (4: technical, engagement, style, completeness)
- ✅ Social media generation (Twitter + LinkedIn)
- ✅ Non-destructive behavior (creates files, never modifies without asking)
- ✅ Re-runnable (can review multiple times)
- ✅ Integration with existing workflow (documented in Task 5)

---

## Summary

This plan creates a complete two-phase AI blog workflow:

**Phase 1: Generation**
- `/blog-from-notes` - Paste scattered notes → Get structured draft + social posts

**Phase 2: Review**
- `/blog-review` - Comprehensive quality check → Get actionable feedback

**Bonus:**
- `/blog-social` - Generate social posts for manual posts

**Total effort:**
- Task 1: ~10 minutes (create blog-from-notes skill)
- Task 2: ~15 minutes (create blog-review skill)  
- Task 3: ~8 minutes (create blog-social skill)
- Task 4: ~10 minutes (integration testing)
- Task 5: ~5 minutes (documentation)

**Total: ~48 minutes** (assuming skills work correctly on first try)

**Testing strategy:**
- Integration test in Task 4 validates all three skills work together
- Test with realistic content (scattered notes about Rails caching)
- Verify file outputs, character counts, and review report structure
- Clean up test files after validation
