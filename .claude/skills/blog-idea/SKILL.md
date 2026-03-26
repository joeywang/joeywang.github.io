---
name: blog-idea
description: Quick capture for blog post ideas - save thoughts for later development
user-invocable: true
disable-model-invocation: true
---

# Blog Idea Capture

Quick way to save blog post ideas when inspiration strikes. Captured ideas can be turned into full posts later with `/blog-workflow`.

## Usage

```
/blog-idea "Setting up Redis caching in Rails - everyone does it wrong"
```

Or invoke without arguments for guided capture:

```
/blog-idea
```

## What to Capture

**Minimum:**
- Topic/title
- Your opinion or angle

**Optional but helpful:**
- Why you care about this
- A quick failure story
- Who it's for
- Relevant tags

## Where Ideas Are Saved

Ideas are saved to `_drafts/ideas.md` in chronological order.

## Example Entry

```markdown
## 2026-03-26: Setting up Redis caching in Rails

**My Take:** Everyone adds Redis caching without thinking about cache invalidation. Then they wonder why their app shows stale data.

**Story:** Spent 2 days debugging "user sees old profile" bug. Turned out we were caching forever with no TTL.

**Audience:** Rails developers optimizing performance

**Tags:** Ruby on Rails, Performance, Redis, Caching

**Status:** Idea captured

---
```

## Workflow

**Capture ideas as they come:**
```
/blog-idea "Topic and angle"
```

**Later, when ready to write:**
```
/blog-workflow
```

Then copy-paste your captured idea as input.

## Quick Templates

### Performance Topic
```
Topic: {specific performance problem}
Take: {common mistake people make}
Story: {your debugging experience}
Numbers: {before/after metrics}
```

### Tool/Setup Topic
```
Topic: {tool setup or configuration}
Take: {why the official docs are incomplete}
Story: {what went wrong in your setup}
Gotcha: {the non-obvious thing that trips everyone up}
```

### Opinion Piece
```
Topic: {contrarian technical opinion}
Take: {why conventional wisdom is wrong}
Experience: {evidence from your work}
Why it matters: {business or technical impact}
```

## Notes

- Don't overthink it - capture the raw idea
- You can always refine when running `/blog-workflow`
- Ideas don't need to be complete - just enough to remember your angle
- Review `_drafts/ideas.md` periodically for inspiration
