# Applied AI / FDE profile review

## Scope and source

- Source repository: `joeywang/joeywang.github.io`, branch `profile/applied-ai-fde`, based on `origin/main` at `50c5d19`.
- The canonical public About page was inspected and reports Jekyll 4.4.1. The separate Astro migration is not the source used for this change.
- Updated: About, homepage introduction, site tagline/description, résumé data, script-free résumé HTML and print CSS, main downloadable résumé PDF, and export/check scripts.
- No push, publication, LinkedIn update, or modification of unrelated drafts.

## Positioning and claim boundaries

Lead with applied AI built on software integration and production engineering. Present FDE as a target direction, not an employment title. Keep official roles and dates unchanged. Label local-model projects as experiments and link to existing technical write-ups. Replace numerical skill ratings with plain skill groups. Do not add customer outcomes, performance metrics, or implied production AI deployments.

The machine-learning integration statement for Kitman Labs already existed in the résumé source; it is retained, not independently employer-verified. Joey should confirm it before publication.

## Owner confirmation needed

- The established employment history ends in July 2024. Confirm the public title, dates, and description for work since then, including whether/how to present ongoing part-time or consulting work. Do not invent a current employer or engagement date.
- Confirm whether to emphasize customer-facing FDE opportunities or hands-on Applied AI roles most strongly.
- The legacy `JoeyW-DevOps.pdf` is unchanged. Updated About/résumé download links use `JoeyW-dev.pdf`.

## Verification observed

Run from the worktree with its pinned Ruby through mise:

```sh
JEKYLL_ENV=production bash scripts/build_resume_pdf.sh
mise exec -- ruby scripts/check_frontmatter.rb
JEKYLL_ENV=production mise exec -- bundle exec jekyll build --destination /mnt/data/.hermes/cache/scratch/joey-profile-site
mise exec -- bundle exec ruby scripts/check_resume.rb /mnt/data/.hermes/cache/scratch/joey-profile-site
mise exec -- bundle exec htmlproofer /mnt/data/.hermes/cache/scratch/joey-profile-site --disable-external --allow-missing-href --no-enforce-https
bash -n scripts/build_resume_pdf.sh
mise exec -- ruby -c scripts/prepare_resume_print.rb
mise exec -- ruby -c scripts/check_resume.rb
git diff --check
```

Results: 247 post front matters passed; production site built; three roles and three evidence links passed résumé checks; 2,964 internal links checked across 589 HTML files with HTML-Proofer success. Ruby/shell syntax and diff whitespace checks passed. External links were not covered by HTML-Proofer.

PDF verified with PyMuPDF: two A4 pages, revised focus and all employers present, no browser error text, no screen navigation or temporary-path headers, and three canonical article links. Both PDF pages and desktop/mobile About screenshots were visually inspected. The export now inlines print CSS because root-relative CSS does not load correctly from a file URL, and exports inside snap-accessible staging before copying to the requested target.
