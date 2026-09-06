---
layout: post
title: "How to Rotate GKE Cluster Credentials"
description: "The gcloud commands for checking certificate expiry, starting rotation, upgrading nodes to the new certificate, and completing GKE credential rotation."
date: 2024-09-03 09:37 +0100
categories: [DevOps]
tags: [gcp, kubernetes, security]
---
<audio controls preload="metadata" src="/assets/audio/google-cloud-container-credential-rotation-a-comprehensive-guide-summary.ogg">
  Your browser does not support the audio element.
</audio>

GKE's master certificate and API server credentials aren't meant to live forever. Rotating them periodically limits how much damage a leaked credential can do, and GCP's Kubernetes Engine has a built-in rotation flow for exactly this.

## Prerequisites

Before you begin the credential rotation process, ensure that you have:

- The necessary permissions to manage the Kubernetes cluster on GCP.
- The Google Cloud SDK installed and configured on your local machine.
- A stable internet connection to interact with GCP services.

## Checking the Expiry Date

It's important to know when your current credentials will expire. You can check this by running the following commands:

```bash
# Check the expiry date of the cluster's master certificate
CLUSTER_NAME=mycluster
REGION_NAME=asia-east1-c
gcloud container clusters describe $CLUSTER_NAME \
    --region $REGION_NAME \
    --format "value(masterAuth.clusterCaCertificate)" \
    | base64 --decode \
    | openssl x509 -noout -dates

# Use openssl to check the certificate of a specific server
openssl s_client -connect $SERVER_IP:443 2>/dev/null | openssl x509 -noout -dates
```

## Initiating the Rotation

Once you've confirmed the need to rotate the credentials, you can initiate the process with this command:

```bash
# Start the credential rotation
CLUSTER_NAME=mycluster
REGION_NAME=asia-east1-c
gcloud container clusters update $CLUSTER_NAME \
    --region $REGION_NAME \
    --start-credential-rotation
```

## Creating a New Node

Updating nodes to communicate with the new IP and certificate is often part of the credential rotation process.

### Manually Triggering the Upgrade

If you need to manually trigger the upgrade of your nodes, use the following command:

```bash
# Manually trigger the node pool upgrade
gcloud container clusters upgrade $CLUSTER_NAME \
    --location=$LOCATION \
    --cluster-version=$VERSION
```

### Checking the Upgrade Progress

Monitor the progress of the node pool recreation and the overall upgrade with these commands:

```bash
# List ongoing operations related to node pool upgrade
gcloud container operations list \
    --filter="operationType=UPGRADE_NODES AND status=RUNNING" \
    --format="value(name)"

# Wait for the operation to complete: Replace OPERATION_ID with the actual operation ID from the command above
gcloud container operations wait $OPERATION_ID

# Update kubectl credentials to the new cluster version
gcloud container clusters get-credentials $CLUSTER_NAME \
    --region $REGION_NAME
```

## Applying New Credentials to Clients

After initiating the credential rotation, update all external API clients to use the new credentials and point to the new control plane IP address.

```bash
gcloud container clusters get-credentials $CLUSTER_NAME \
    --region $REGION_NAME
```

## Completing the Rotation

With the new nodes updated and communicating with the new IP and certificate, you can complete the credential rotation:

```bash
# Complete the credential rotation
CLUSTER_NAME=mycluster
REGION_NAME=asia-east1-c
gcloud container clusters update $CLUSTER_NAME \
    --region=$REGION_NAME \
    --complete-credential-rotation
```

## The sequence

Start rotation, upgrade nodes to pick up the new certificate and IP, point every client at the new credentials, then complete the rotation. Skip the node upgrade step and clients will keep hitting the old control plane IP until it's retired, which is the failure mode worth watching for. The [official documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/credential-rotation) covers edge cases like private clusters and Workload Identity in more depth.
