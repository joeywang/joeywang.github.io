---
title: "Identity-Aware GCS Access Instead of Hashed Secret URLs"
description: "Replacing hashed 'secret' URLs in Google Cloud Storage with IAM Conditions and domain-restricted access that verifies identity instead of hiding a path."
date: 2026-03-13
categories: [DevOps, Security]
tags: [gcp, security, devops, iam]
layout: post
---

<audio controls preload="metadata" src="/assets/audio/gcp-controlled-share-summary.ogg">
  Your browser does not support the audio element.
</audio>

In twenty years of moving data around, from physical tapes to local SANs and now the cloud, I've seen one "security" shortcut come back more often than any other: the secret URL. You have a file to share with a specific group, so you hash the path, something like `my-bucket/a87f2-bc91-0012-ff32/report.pdf`, and send it out on the assumption that a long random string counts as private.

It doesn't. If that link ends up in a browser history, a Slack log, or a server header, the file is public. In 2026, security through obscurity is not a strategy, it's a liability. Here is how to do it properly with identity-aware access on Google Cloud instead.

## The design: verify identity, not the path

For an internal domain like `@example.com`, the fix is not a longer hash. It's three layers of defense that check who someone is rather than whether they guessed a URL:

1. **Uniform Bucket-Level Access (UBLA)**, so permissions are centralized instead of scattered across legacy per-object ACLs.
2. **Public Access Prevention (PAP)**, a hard no to the open internet at the API level.
3. **IAM Conditions**, a rule that says: you can see this folder only if you're logged into our domain.

## Step 1: create a hardened bucket

Set the security perimeter at creation time, not after the fact:

```bash
gcloud storage buckets create gs://re-internal-assets \
    --location=us-central1 \
    --uniform-bucket-level-access \
    --public-access-prevention
```

`--public-access-prevention` is worth treating as non-negotiable. Even if someone later tries to make an object public, GCP blocks the request at the API level rather than relying on anyone remembering not to.

## Step 2: scope access with an IAM Condition

Granting the whole domain `storage.objectViewer` on the bucket is too broad. An IAM Condition restricts that grant to one prefix:

```bash
gcloud storage buckets add-iam-policy-binding gs://re-internal-assets \
    --member="domain:example.com" \
    --role="roles/storage.objectViewer" \
    --condition='expression=resource.name.startsWith("projects/_/buckets/re-internal-assets/objects/shared-docs/"),title=Internal_Folder_Only,description=Restrict_access_to_shared_docs_prefix'
```

Compared to a hashed path, this gets you three things a hash never gives you: no password sharing, since users have to be logged into their company Google account; a leaked URL is worthless to anyone outside the domain, since they get a 403 instead of a download; and you can finally use readable paths like `/shared-docs/` instead of `7a82b-xyz`.

## Step 3: turn on the audit log

Locking the door isn't enough if you can't tell who walked through it. By default, GCS "Data Access" logs are off to save on storage costs, so you have to enable them:

1. Go to **IAM & Admin > Audit Logs** in the console.
2. Select **Google Cloud Storage**.
3. Enable **Data Read** and **Data Write**.

Once that's on, this query in Logs Explorer shows who from the domain touched what:

```sql
-- See who from the domain accessed the files
logName="projects/YOUR_PROJECT_ID/logs/cloudaudit.googleapis.com%2Fdata_access"
protoPayload.serviceName="storage.googleapis.com"
protoPayload.authenticationInfo.principalEmail:"@example.com"
```

## Scripting it so it's repeatable

Manual steps are where mistakes creep in. This script deploys the same pattern on demand:

```bash
#!/bin/bash
# Secure GCS setup script

PROJECT_ID=$(gcloud config get-value project)
BUCKET_NAME="re-secure-storage-$(date +%s)"
DOMAIN="example.com"
FOLDER="internal-only"

echo "Initializing secure storage for $DOMAIN..."

# 1. Create bucket
gcloud storage buckets create gs://$BUCKET_NAME \
    --project=$PROJECT_ID \
    --uniform-bucket-level-access \
    --public-access-prevention

# 2. Bind domain with path condition
gcloud storage buckets add-iam-policy-binding gs://$BUCKET_NAME \
    --member="domain:$DOMAIN" \
    --role="roles/storage.objectViewer" \
    --condition="expression=resource.name.startsWith(\"projects/_/buckets/$BUCKET_NAME/objects/$FOLDER/\"),title=Domain_Restriction"

echo "Deployment complete"
echo "Bucket: gs://$BUCKET_NAME"
echo "Restricted folder: /$FOLDER/"
echo "Note: enable Data Access logs in IAM settings for full auditability."
```

## The point

A hashed path is security theater. It works only as long as nobody ever sees the URL, and URLs leak constantly: browser history, chat logs, referrer headers, screenshots. Identity-aware access doesn't have that failure mode, because the check happens on every request against who is actually asking, not against whether the string in the address bar looks random enough. That's the whole difference between hiding a file and controlling access to it.
</content>
