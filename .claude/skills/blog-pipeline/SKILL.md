---
name: blog-pipeline
description: Run the staged research, writing, review, privacy, publication, social, and voice workflow.
user-invocable: true
disable-model-invocation: true
---

# Blog Pipeline

Use `docs/blog-agent-pipeline.md` as the contract and coordinate the bounded agents in `.claude/agents/`.

## Required sequence

1. Collect Joey's topic, angle, experience, audience, source boundary, and desired publication timing.
2. Run `research-scout` for public sources and a claim/source map.
3. Run `article-writer` with Joey's brief plus the research handoff. Save only to `_drafts/`.
4. Run the independent `content-reviewer`. Stop for blocking quality issues.
5. Run `privacy-humanizer`. Preserve the redaction log and stop for unresolved privacy questions.
6. Show Joey the draft, review verdict, redaction summary, and proposed publication diff. Require explicit approval before publication.
7. Run `publication-verifier`; build and link-check the site. Do not merge or deploy without matching approval.
8. After a verified canonical URL, run `social-summary`; save X and LinkedIn drafts. Do not post or queue Buffer content without separate approval.
9. Run `voice-summary`; generate local Piper audio and verify the asset.
10. Update the relevant `re-work` record with state, evidence, links, next action, and any GitHub/Jira references. Never store secrets or unnecessary PII.

## Handoff format

After each stage, report:

```text
stage: <name>
status: <completed|needs_revision|blocked|awaiting_approval>
artifacts: <paths>
evidence: <checks or source summary>
next_gate: <what Joey must approve, if anything>
```

Never invent personal experience, sources, metrics, publication URLs, review results, or deployment status. Keep unrelated worktree changes untouched.
