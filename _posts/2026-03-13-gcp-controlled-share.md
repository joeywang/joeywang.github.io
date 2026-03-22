---
title: "Stop Hiding, Start Securing: Moving from Hashed Paths to Identity-Aware GCS"
date: 2026-03-13
categories: GCP
layout: post
---

# Stop Hiding, Start Securing: Moving from Hashed Paths to Identity-Aware GCS

In my twenty years of moving data—from physical tapes to local SANs and now the cloud—I’ve seen one "security" shortcut pop up more than any other: **The Secret URL.**

We’ve all done it. You have a file you want to share with a specific group, so you hash the path: `my-bucket/a87f2-bc91-0012-ff32/report.pdf`. You send it out and assume that because the string is long and random, it's "private."

**It isn’t.**

If that link is in a browser history, a Slack log, or a server header, your data is public. In 2026, "Security through Obscurity" isn't a strategy; it's a liability. Today, I’m going to show you how to do it the right way using **Identity-Aware Storage** on Google Cloud.

---

## The "Triple-Lock" Architecture

When we design for a professional environment—specifically for internal domains like `@reallyenglish.com`—we don't rely on the *path* being secret. We rely on the *identity* being verified. 

We are going to implement three layers of defense:
1.  **Uniform Bucket-Level Access (UBLA):** We kill legacy ACLs so permissions are centralized.
2.  **Public Access Prevention (PAP):** A hard "No" to the open internet.
3.  **IAM Conditions:** A granular rule that says: *"You can only see this folder if you are logged into our domain."*

---

## Step 1: Provisioning the Hardened Bucket

First, we create the bucket. We aren't just making a folder; we are setting a security perimeter.

```bash
gcloud storage buckets create gs://re-internal-assets \
    --location=us-central1 \
    --uniform-bucket-level-access \
    --public-access-prevention
```

> **Pro Tip:** Enabling `--public-access-prevention` is your insurance policy. Even if a junior dev tries to make a file public later, GCP will block the request at the API level.

---

## Step 2: The Logic of Identity-Based Paths

Now, we grant access to the domain. But we don't want everyone seeing *everything*. We use an **IAM Condition** to restrict them to a specific prefix (folder).

```bash
gcloud storage buckets add-iam-policy-binding gs://re-internal-assets \
    --member="domain:reallyenglish.com" \
    --role="roles/storage.objectViewer" \
    --condition='expression=resource.name.startsWith("projects/_/buckets/re-internal-assets/objects/shared-docs/"),title=Internal_Folder_Only,description=Restrict_access_to_shared_docs_prefix'
```

### Why this is better than a hash:
* **No Password Sharing:** Users must be logged into their company Google account.
* **Leak-Proof:** If the URL leaks to a competitor, they get a `403 Forbidden` because they aren't on the `@reallyenglish.com` domain.
* **Readable Paths:** You can finally use clear names like `/shared-docs/` instead of `7a82b-xyz`.

---

## Step 3: Accountability (The Audit Log)

In a professional setup, you don't just lock the door; you install a camera. We need to know who downloaded what. By default, GCS "Data Access" logs are off to save on storage costs. We need to flip the switch.

1.  Navigate to **IAM & Admin > Audit Logs** in the GCP Console.
2.  Select **Google Cloud Storage**.
3.  Enable **Data Read** and **Data Write** logs.

Once enabled, you can run this query in **Logs Explorer** to see your team's activity:

```sql
# See who from the domain accessed the files
logName="projects/YOUR_PROJECT_ID/logs/cloudaudit.googleapis.com%2Fdata_access"
protoPayload.serviceName="storage.googleapis.com"
protoPayload.authenticationInfo.principalEmail:"@reallyenglish.com"
```

---

## The Automation Script

I’ve spent enough time in the CLI to know that manual steps lead to mistakes. Use this script to deploy your secure shares.

```bash
#!/bin/bash
# Secure GCS Setup Script v1.0

PROJECT_ID=$(gcloud config get-value project)
BUCKET_NAME="re-secure-storage-$(date +%s)"
DOMAIN="reallyenglish.com"
FOLDER="internal-only"

echo "Initializing Secure Storage for $DOMAIN..."

# 1. Create Bucket
gcloud storage buckets create gs://$BUCKET_NAME \
    --project=$PROJECT_ID \
    --uniform-bucket-level-access \
    --public-access-prevention

# 2. Bind Domain with Path Condition
gcloud storage buckets add-iam-policy-binding gs://$BUCKET_NAME \
    --member="domain:$DOMAIN" \
    --role="roles/storage.objectViewer" \
    --condition="expression=resource.name.startsWith(\"projects/_/buckets/$BUCKET_NAME/objects/$FOLDER/\"),title=Domain_Restriction"

echo "DEPLOYMENT COMPLETE"
echo "Bucket: gs://$BUCKET_NAME"
echo "Restricted Folder: /$FOLDER/"
echo "Note: Ensure 'Data Access' logs are enabled in IAM settings for full auditability."
```

---

## Final Thoughts from the Field

If you're still using hashed paths to "protect" data, you're living in 2010. Modern cloud security is about **Identity**. By using the method above, you aren't just hiding files—you're building a verifiable, auditable, and truly private repository that scales with your team.

**Stay secure.**
