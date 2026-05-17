# Blog AI Workflow Design

**Date:** 2026-05-17  
**Author:** Joey Wang  
**Status:** Approved

## Overview

A two-phase AI-assisted blog workflow that transforms scattered notes into polished technical articles with comprehensive quality review.

**Problem:** Turning rough ideas (scattered bullet points, brain dumps from notes apps, social media, bookmarks) into well-structured blog posts.

**Solution:** Two-phase pipeline:
1. `/blog-from-notes` - Generate draft from scattered notes
2. `/blog-review` - Comprehensive review (technical accuracy, engagement, style, completeness)

## Architecture

### Workflow

```
Raw Notes (scattered sources)
    ↓
/blog-from-notes
    ↓
Draft Post (_posts/YYYY-MM-DD-slug.md)
    ↓
/blog-review
    ↓
Review Report + Inline Suggestions
    ↓
Manual Edits
    ↓
(Optional) Re-run /blog-review
    ↓
Publish
```

### Key Principles

- **Phase 1 (generation):** Fast, opinionated, gets you 80% of the way there
- **Phase 2 (review):** Thorough, catches what generation missed
- **Iterative:** Can edit and re-review multiple times without regenerating

### Integration with Existing Workflow

Three ways to create posts:

1. **Structured Q&A (existing):** `/blog-workflow`
   - When: Clear idea, want guided prompts
   - Process: Answer 6 questions → AI generates post

2. **Notes Dump (new):** `/blog-from-notes`
   - When: Scattered notes across multiple places
   - Process: Paste everything → AI structures and generates

3. **Manual (existing):** Write directly in `_posts/`
   - When: Prefer total creative control
   - Process: Write markdown file manually

All three paths converge at `/blog-review` for quality assurance.

## Component 1: `/blog-from-notes` Skill

### Purpose
Transform scattered notes into a structured, humanized blog post draft.

### Input Format
User pastes everything in one message - any combination of:
- Bullet points from notes apps
- Social media posts they want to expand
- Bookmark annotations
- Code snippets
- Brain dump paragraphs
- Screenshots of notes (AI reads text)

### Processing Steps

1. **Extract & Organize:**
   - Identify main topic/angle
   - Group related points into logical sections
   - Detect personal stories, failures, gotchas, numbers
   - Identify missing gaps (flag if critical context missing)

2. **Generate Structure:**
   - Create section outline based on content
   - Map notes to sections (which points go where)
   - Identify hook (failure story or contrarian opinion)

3. **Write Full Draft:**
   - Apply humanized writing style (from existing blog-workflow template)
   - Weave in personal stories and specific numbers
   - Add emojis to section headers
   - Include code examples with personality
   - Write conversational opening/conclusion

4. **Auto-generate Social Posts:**
   - Twitter: Hook + one-liner + URL
   - LinkedIn: Expanded hook + bullet points + question

### Output

Creates three files:
- `_posts/YYYY-MM-DD-slug.md` - The blog post
- `static/twitter-slug.md` - Twitter post
- `static/linkedin-slug.md` - LinkedIn post

Console output:
```
✅ Draft created: _posts/2026-05-17-topic-slug.md

Organized from your notes:
• Hook: [failure story or opinion]
• 5 main sections identified
• 2 personal stories included
• 3 code examples added

Social posts ready:
• Twitter: static/twitter-slug.md
• LinkedIn: static/linkedin-slug.md

Next: Run /blog-review to get comprehensive feedback
```

### Edge Cases

- **Notes too sparse (< 3 substantial points):** Ask for more context
- **Multiple topics detected:** Ask which to focus on
- **No clear hook found:** Generate options and ask user to pick

## Component 2: `/blog-review` Skill

### Purpose
Comprehensive review across technical accuracy, engagement, style consistency, and completeness.

### Input

- **No argument:** Automatically detects most recent post in `_posts/` (by filename date, YYYY-MM-DD prefix)
- **With path:** `/blog-review _posts/2026-05-17-specific-post.md` to review a specific post

### Review Dimensions

#### 1. Technical Accuracy (⚙️)
- Code examples are correct and runnable
- Commands/configurations are current (not outdated)
- Technical claims are accurate
- Dependencies/versions mentioned are compatible
- Links to docs are valid

#### 2. Engagement & Readability (📖)
- Opening hook is strong (not generic "In this post...")
- Section headers have personality + emojis
- Personal stories are specific (dates, numbers, emotions)
- Transitions between sections flow naturally
- Conclusion is conversational (not just summary)
- Paragraphs aren't too long (< 5 lines)

#### 3. Style Consistency (🎨)
- Voice matches your other posts (conversational, first-person)
- Uses "I" and "you" naturally
- Includes failure stories and lessons learned
- Code comments have personality
- No corporate jargon ("leverage", "utilize", "implement")
- Contractions used appropriately

#### 4. Completeness (✅)
- Key gotchas explained
- Edge cases addressed
- "Why" not just "what"
- Cost/time estimates realistic
- Prerequisites mentioned
- Follow-up resources included

### Output Format

Creates `static/review-reports/YYYY-MM-DD-slug-review.md`:

```markdown
# Review: [Post Title]
Date: 2026-05-17
Status: READY | NEEDS WORK

## Overall Assessment
[2-3 sentence summary of post quality and main issues]

---

## ⚙️ Technical Accuracy
### ✅ Strengths
- [What's technically correct]

### ⚠️ Issues
- Line X: [Problem description]
  **Fix:** [Specific suggested fix]

---

## 📖 Engagement & Readability
### ✅ Strengths
- [What's engaging]

### ⚠️ Issues
- [Problem with line number]
  **Suggestion:** [Specific improvement]

---

## 🎨 Style Consistency
### ✅ Strengths
- [What matches style]

### ⚠️ Issues
- [Style inconsistencies with fixes]

---

## ✅ Completeness
### ✅ Strengths
- [What's complete]

### ⚠️ Issues
- Missing: [What's missing]
  **Suggestion:** [What to add]

---

## Summary & Next Steps

**Status: READY | NEEDS WORK** (X issues)

**Priority fixes:**
1. [Must-fix items with line numbers]

**Optional improvements:**
- [Nice-to-have suggestions]

**After fixes:**
- Run `/blog-review` again to verify
- Or proceed to publish if satisfied
```

### Behavior

- **Non-destructive:** Review only, never edits the post
- **Actionable:** Every issue includes specific line number + suggested fix
- **Prioritized:** Distinguishes "must fix" from "nice to have"
- **Re-runnable:** Can review same post multiple times after edits

## Component 3: `/blog-social` Skill (Bonus)

### Purpose
Generate social media posts for manually written blog posts.

### Usage
```
/blog-social _posts/2026-05-17-my-manual-post.md
```

### Output
- `static/twitter-my-manual-post.md`
- `static/linkedin-my-manual-post.md`

Fills the gap for manual posts that don't go through `/blog-workflow` or `/blog-from-notes`.

## File Structure

```
joeywang.github.io/
├── _posts/
│   └── YYYY-MM-DD-title-slug.md
├── static/
│   ├── twitter-title-slug.md
│   ├── linkedin-title-slug.md
│   └── review-reports/
│       └── YYYY-MM-DD-title-slug-review.md
├── .claude/
│   ├── skills/
│   │   ├── blog-workflow/          (existing)
│   │   ├── blog-from-notes/        (new)
│   │   ├── blog-review/            (new)
│   │   └── blog-social/            (new)
│   └── settings.json
└── docs/superpowers/specs/
    └── 2026-05-17-blog-ai-workflow-design.md
```

## Example End-to-End Usage

### Scenario
You have scattered notes about "Rails performance optimization" across Apple Notes, a Twitter thread, and code snippets.

### Step 1: Generate Draft

```
User: /blog-from-notes

[Pastes:]
- Apple Notes: "Rails app slow after 1000 users. Tried N+1 fixes, didn't help. 
  Real issue was eager loading wrong associations. Cost me 2 days debugging."

- Twitter thread: "Hot take: Most Rails perf guides focus on N+1 queries, 
  but in my experience, the real killer is loading too much data you don't need. 
  includes() is not always the answer."

- Code snippets:
  User.includes(:posts, :comments).where(active: true)  # SLOW
  User.includes(:posts).where(active: true)             # FAST

- Bookmark annotation: "includes() loads ALL associations into memory"
```

**AI Output:**
```
✅ Draft created: _posts/2026-05-17-rails-performance-eager-loading-trap.md

Organized from your notes:
• Hook: 2-day debugging story
• 4 main sections identified
• Personal failure story included
• Code examples showing slow vs fast approach

Social posts ready:
• Twitter: static/twitter-rails-performance-eager-loading-trap.md
• LinkedIn: static/linkedin-rails-performance-eager-loading-trap.md

Next: Run /blog-review to get comprehensive feedback
```

### Step 2: Comprehensive Review

```
User: /blog-review

AI Output:
Created: static/review-reports/2026-05-17-rails-performance-eager-loading-trap-review.md

Status: NEEDS WORK (2 technical issues, 3 engagement improvements)

Priority fixes:
1. Line 45: Code example missing context about dataset size
2. Line 78: "Leverage eager loading" → Use "Use eager loading"
3. Missing: How to profile which associations are slow
```

### Step 3: Edit Based on Feedback

User edits `_posts/2026-05-17-rails-performance-eager-loading-trap.md`

### Step 4: Re-review

```
User: /blog-review

AI Output:
Status: READY ✅

All issues addressed. Post is ready to publish.
```

### Step 5: Publish

```bash
git add _posts/2026-05-17-rails-performance-eager-loading-trap.md
git add static/twitter-rails-performance-eager-loading-trap.md
git add static/linkedin-rails-performance-eager-loading-trap.md
git commit -m "Add post: Rails Performance Eager Loading Trap"
git push origin main
```

## Implementation Requirements

### `/blog-from-notes` Skill

**Required:**
- Note parsing and extraction logic
- Section organization algorithm
- Humanized writing style template (reuse from `/blog-workflow`)
- Social media post generation (reuse from existing workflow)
- Frontmatter generation (title, date, tags, categories)

**Technical:**
- Must handle multiple input formats (bullets, paragraphs, code, screenshots)
- Must detect and extract: topic, opinion, stories, numbers, gotchas
- Must generate proper Jekyll frontmatter
- Must create valid markdown

### `/blog-review` Skill

**Required:**
- Technical accuracy checker
  - Code syntax validation
  - Framework version compatibility checks
  - Link validation
- Engagement analyzer
  - Hook detection
  - Personal story detection
  - Paragraph length analysis
  - Header personality check
- Style consistency checker
  - Voice analysis (first-person, conversational)
  - Jargon detection
  - Contraction usage
- Completeness checker
  - Prerequisites check
  - Gotcha detection
  - Cost/time estimate presence

**Technical:**
- Must parse markdown with line numbers
- Must generate structured review report
- Must distinguish priority fixes from optional improvements
- Must be re-runnable without side effects

### `/blog-social` Skill

**Required:**
- Twitter post generator (max 280 chars)
- LinkedIn post generator (500-1000 chars)
- URL construction from post filename
- Tag/hashtag generation

**Technical:**
- Must read existing blog post
- Must extract key points
- Must format for each platform

## Success Criteria

This workflow succeeds when:

✅ User spends 2-5 minutes pasting scattered notes  
✅ Generated post sounds authentic (personal, conversational)  
✅ Review catches technical, engagement, style, and completeness issues  
✅ Review is actionable (line numbers, specific fixes)  
✅ User can iterate (edit → re-review) without regenerating  
✅ Social posts capture the hook and key points  
✅ Clear path from scattered notes to published post  

## Non-Goals

- ❌ Automated note capture from external sources (too complex for v1)
- ❌ Real-time collaboration or multi-user editing
- ❌ Automated publishing (git push remains manual)
- ❌ SEO optimization or keyword research
- ❌ Image generation or diagram creation

## Future Enhancements

**V2 possibilities:**
- MCP integration for Apple Notes, browser bookmarks
- Automated note capture by tag/keyword
- A/B testing for social media posts
- SEO keyword research integration
- Image/diagram generation for technical concepts
- Analytics integration (track which posts perform best)

## References

- Existing `/blog-workflow` skill in `.claude/skills/blog-workflow/`
- Jekyll blog configuration in `_config.yml`
- Chirpy theme documentation
- CLAUDE.md project instructions
