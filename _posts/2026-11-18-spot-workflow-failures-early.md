---
layout: post
title: "How to spot workflow failures before users do"
date: 2026-11-18 14:50:00 +0000
author: joeywang
description: "Detect workflow failures earlier by checking the result users depend on, setting a deadline for missing work, and showing responders where to look first."
tags: [automation, debugging, testing, devops]
categories: [Engineering]
---

A nightly report job exits successfully. The dashboard is green. At nine the next morning, someone downloads yesterday's file because no one checked what the download link actually served.

This is an illustrative example, but the distinction matters: a worker can finish without delivering the result anyone needs. The first check I want is one that would fail in that situation. My [agent development runbook](/posts/ai-agent-development-runbook/) asks for evidence before handing off a change. The same question applies once a workflow is running: what proves the result reached the next person or system?

## Start at the handoff and work backwards

For the report, success means that an authorised reader can open a valid file for the expected reporting date through the normal download route. A zero exit code, a new object in storage, or an HTTP 200 does not establish that. The route may still point to the old file. And a newly generated report with zero rows may be entirely correct.

Start with one check that uses the reader's route and verifies the format and reporting period. If the report has a trusted manifest, the check can compare the downloaded file with its checksum. That establishes that the expected file was served, not that every number in it is right. A separate reconciliation check is needed if a wrong total is a serious risk. Use a narrowly authorised monitor identity, and record the period and verdict, not the contents of the report.

## Give silence a deadline

A check inside the report job cannot tell you that the scheduler never started it. Run the deadline check independently, and have the alerting system expect a heartbeat from that check too. A missed heartbeat means the check has gone quiet; it does not prove that reporting failed.

Suppose readers need the report at 09:00, and the team wants 45 minutes for investigation and recovery. The first usable copy is then due at 08:15. Use that as the latest point to notify the owner if the current report is missing, stale, or invalid. Use the workflow's actual calendar and time zone to calculate which report is due. A monitor that expects a Sunday file from a weekday job will teach people to ignore it.

An individual retry can stay in the logs if there is still time to finish. Notify the owner sooner if the job hits a terminal error or if the remaining retries would use up the time reserved for recovery. If the usual completion time leaves no room for that buffer, start the job earlier or fix the slow stage. Telling the monitor to check more often will not buy back those minutes.

## Put the first diagnostic step in the alert

The end-to-end check tells the owner that the outcome is wrong. A few stage records, tied to the same run ID and reporting period, can tell them where to look. An alert for a stale download might read:

```text
Daily report: expected 17 Nov; download serves 16 Nov.
Deadline: 08:15 local. Run: report-17-nov.
Last confirmed step: new file written at 07:56.
First check: compare the download pointer to the uploaded file.
Owner: reporting on-call. Runbook: daily report recovery.
```

If the run never started, there is no run ID to link. Point to the scheduler history for the expected period instead. If the file was written but the old one is still served, check the pointer or cache before rerunning the export. The last confirmed step narrows the search; it does not establish the root cause.

Group repeats for the same reporting period into one incident. Close it when the reader-facing check passes again, not when someone clicks retry. Before wiring up automatic retries, check whether repeating the job can send another notification, overwrite a good file, or repeat another side effect.

## Test the alert with a deliberately stale file

In a test environment, serve yesterday's valid file with a 200 response while the export job reports success. The deadline check should identify the wrong period and route the alert to the owner. Then skip a scheduled run and confirm that silence is detected without help from the worker. Finally restore today's file and confirm the alert clears. Exercise notification delivery too: a failed assertion in a dashboard nobody watches is not a useful alarm.

For the first rollout, I would pick one workflow people already check by hand. Record when the result first became wrong, when the owner heard about it, and when they found the failing stage. Those timestamps tell you what to improve next: a check that notices sooner, a notification that reaches someone, or an alert that points to the right place.
