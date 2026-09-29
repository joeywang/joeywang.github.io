---
layout: post
date: 2026-09-01 00:00:00 +0100
author: "Joey Wang"
title: "Recovering a hacked WordPress site: why I rebuilt instead of patching"
description: "Lessons from a WordPress recovery: preserve evidence, rebuild from a reviewed baseline, test real behaviour, and be precise about what the checks prove."
tags: [wordpress, security, incident-response, recovery, backups]
categories: [Engineering]
---

A WordPress site I maintained was compromised. The investigation found unauthorised administrator accounts and malicious changes across several parts of the application.

By that point, resetting a password and deleting a suspicious plugin would not have been enough. I needed a reason to trust the code and database again.

I chose to rebuild from a reviewed pre-incident baseline, test a separate recovery candidate, and replace the affected installation through a controlled cutover. The recovery also uncovered ordinary application problems: missing plugin activation, broken images, and a theme widget displaying content it should not have displayed.

Those repairs were part of getting the site back, too.

*This account omits identifying details, incident dates, infrastructure information, and exploit mechanics. It describes the recovery decisions and checks recorded at the time, rather than claiming anything about the site's current security.*

## Establish what the evidence supports

The investigation drew on access logs, a copy of the affected code, and database records. Each answered a different question.

The logs helped establish a sequence of administrative activity. The code showed malicious modifications. Database records showed unauthorised accounts and changes to application state. Together, they supported a much stronger conclusion than any isolated request or suspicious filename.

They did not establish the original entry point conclusively.

That distinction matters. Evidence of an attacker using administrative access does not, by itself, explain how they obtained it. A stolen password, an earlier vulnerability, and an existing backdoor are different explanations. I could not honestly choose one just because it made the story easier to tell.

I also could not use a successful recovery to conclude that no information had been accessed. Restoring an application and assessing the impact of a compromise are separate jobs.

## Preserve the affected state before replacing it

Before destructive cleanup, I preserved copies of the code, database, and available logs. Backup verification and independently stored copies gave me something to return to during the investigation.

There is an important distinction between an evidence copy and a recovery copy. The affected installation was useful for understanding what happened. That did not make it suitable to put back online.

In a live incident, containment may need to happen immediately to protect visitors and prevent further changes. Preserving evidence should support that response, not become an excuse to leave a harmful site running.

A checksum has a similarly limited purpose. It can show that a copied archive matches the original archive. It cannot show that the original archive was free of malicious code.

## Why I chose a rebuild

Malicious changes were spread across the installation rather than confined to one removable component. That made an in-place cleanup difficult to verify. Deleting everything I had found would still leave the question of what I had missed.

A separate recovery candidate gave me a clearer basis for comparison. I could review the earlier baseline, check the expected users and application state, and test the candidate before switching the live site over.

An older backup is not automatically trustworthy. It may predate the visible symptoms without predating the compromise. It may also contain outdated software. A sound recovery process needs both a reviewed baseline and supported software from trusted sources; blindly restoring an old archive can restore old vulnerabilities along with the content.

The same caution applies to the database. Replacing application files does not remove an unauthorised account or repair altered settings. The recovery had to consider code and data together.

## Keep the recovery candidate separate

I prepared the candidate without immediately overwriting the affected installation. This preserved the evidence and allowed checks before cutover.

Code and database state were treated as one release. A tested code directory connected to the wrong database state would not have been the candidate I had verified.

Before destructive database cleanup, I made and verified another backup. This mattered because the recovery procedure changed once the old data was removed. Reversing a directory change would no longer be enough; restoring data would also be necessary.

For a security incident, a rollback plan must be explicit about where it leads. It should provide a safe maintenance state or a reviewed recovery version. Re-enabling a known-compromised installation is not a safe fallback simply because it is convenient.

## The restored site still needed repair

After the code switch, some pages did not behave as expected.

Required plugins were present on disk but were not active in the restored application state. That left page components and a contact form displaying incorrectly. Image delivery also needed attention, and an empty theme widget still displayed built-in default content.

These were useful reminders of how much behaviour sits outside the files themselves. A plugin directory can exist without its functionality being available. A page can return a successful response while showing broken content.

The recorded follow-up checks confirmed that affected page components and the contact form rendered again, and that the checked images loaded correctly. That is a narrower claim than saying every workflow passed. A visible form does not prove submission works or that its email reaches the intended inbox.

For a recovery checklist, I would include representative pages, media, login and permissions, form submission, email delivery, and any external integrations the site depends on. Each needs its own observed result.

## What the recovery checks proved

The recovery record showed that the replacement site served the checked pages, expected accounts remained, identified unauthorised accounts were absent, and known malicious components were no longer present in the candidate. Existing WordPress login sessions were invalidated as part of the response.

Those were useful results. They were not proof that every possible persistence mechanism had been eliminated or that all potentially exposed credentials had been replaced.

Likewise, a scan that finds none of the previously identified malicious patterns is evidence about those patterns. It is not a certificate that the whole environment is safe.

I want an incident report to say exactly what was checked and what passed. Recommendations should stay recommendations until someone implements and verifies them. Credential replacement, stronger authentication, least privilege, supported dependencies, and protected backups belong in a general recovery plan, but listing them is not evidence of completion.

## Make backups testable

The backup work after the recovery focused on making failures visible and copies verifiable. Archive readability, checksums, and copies held separately from the hosting account are all useful checks.

They still do not replace a restore test.

A backup can be readable while missing something the application needs. An incremental archive can be valid while depending on another archive that has been lost. A database dump can import successfully while the restored application fails to behave correctly.

A small restore fixture was exercised during the follow-up work. That helped test the mechanics, but it was not an end-to-end rehearsal of the entire live site. Keeping that distinction in the record makes the next piece of work clear.

## Monitor without making automatic destructive changes

A follow-up integrity check was introduced to detect unexpected changes to application files and important administrative state. Its job was to report changes for review, not delete files on its own.

That separation was deliberate. Legitimate updates change files too. A detector needs an understood baseline, reliable alert delivery, and a person who can distinguish an approved change from something that needs investigation.

The baseline itself must come from a reviewed state. Otherwise, monitoring can faithfully tell you that an already-compromised installation has not changed.

## What I would carry into the next recovery

The most useful decision was to stop treating the task as a search for a few bad files. Once changes were spread across code and accounts, a separate, reviewed recovery candidate was easier to reason about than repeated edits to the affected installation.

The ordinary application checks mattered just as much to completing the work. Users need functioning pages and forms, not merely a server that responds.

I would use the same approach again: contain the incident, preserve what is needed for investigation, rebuild from reviewed sources, test the behaviour people depend on, and record the limits of the evidence. Recovery is easier to review when every claim has a check behind it and every unverified item remains visible.

## Further reading

- [WordPress: FAQ — My site was hacked](https://wordpress.org/documentation/article/faq-my-site-was-hacked/)
- [WordPress: Hardening WordPress](https://developer.wordpress.org/advanced-administration/security/hardening/)
