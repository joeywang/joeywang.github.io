---
layout: post
title: "Giving Hermes Read-Only Access to GCP, AWS, and Kubernetes"
date: 2026-07-18 18:38:00 +0100
author: "Joey Wang"
description: "A practical setup for giving an AI agent enough read-only access to debug QA and production on GCP, AWS, GKE, and EKS without giving it permission to change workloads or read secrets."
tags: [hermes, ai-agents, kubernetes, gcp, aws, gke, eks, security, devops]
categories: [AI, DevOps]
---

# Giving Hermes read-only access to GCP, AWS, and Kubernetes

<audio controls preload="metadata" src="/assets/audio/2026-07-18-read-only-cloud-kubernetes-access-for-hermes-summary.ogg">
  Your browser does not support the audio element.
</audio>

I wanted Hermes to help me investigate QA and production problems.

The useful version of that is not pasting a screenshot of a failed pod into a chat. I want the agent to inspect the current deployment, compare replicas, read events and logs, check CPU and memory, then search the matching application repository. That gives it enough context to answer questions such as:

```text
Why did this deployment stop becoming ready?
Which pod is using most of the memory?
Did the error start after the latest rollout?
Where in the application does this log message come from?
```

The uncomfortable part is access. A normal developer kubeconfig often has far more permission than an investigation needs. Giving that identity to an agent would mean it could restart workloads, change deployments, open a shell in a pod, or read every Kubernetes Secret.

I did not want that.

The setup I settled on has two authorization layers:

```text
Hermes
  -> dedicated cloud identity
     -> read cloud metadata, logs, and metrics
     -> connect to one Kubernetes cluster
        -> read selected resources in selected namespaces
        -> no writes
        -> no pod exec
        -> no Secret access
```

The same shape works on GCP with GKE and on AWS with EKS. The commands differ, but the boundary is the same.

## Cloud read-only and Kubernetes read-only are separate

This is the first detail that is easy to miss.

Cloud IAM controls whether an identity can discover a cluster, fetch its endpoint, and read services such as Cloud Logging or CloudWatch. Kubernetes authorization controls what the identity can do after it reaches the Kubernetes API.

A cloud role called "viewer" does not automatically mean the Kubernetes permission set is safe. It may be broader than expected, and provider integrations can use cloud IAM as part of Kubernetes authorization.

For GKE, Google documents that authorization checks Kubernetes RBAC first and can then fall back to IAM. I therefore prefer a narrow GCP role that only allows the identity to connect to and describe the cluster, followed by an explicit Kubernetes `Role` in each namespace.

For EKS, access entries and EKS access policies provide a similar split. The IAM role reaches the cluster. `AmazonEKSViewPolicy` controls which Kubernetes resources it can view.

## Decide what debugging actually requires

My first list was smaller than I expected:

- pods and their status
- pod logs
- deployments, ReplicaSets, StatefulSets, and DaemonSets
- jobs and CronJobs
- services, endpoints, and ingresses
- autoscalers
- events
- pod CPU and memory metrics
- cloud logs and monitoring metrics

It did not require:

- creating, patching, or deleting resources
- scaling deployments
- restarting pods
- `kubectl exec`, attach, proxy, or port-forward
- reading Kubernetes Secrets
- changing cloud IAM
- deploying new images

Logs deserve their own warning. Read-only logs can still contain email addresses, request bodies, authorization headers, customer IDs, and badly handled tokens. Preventing `get secrets` is necessary, but it does not make every readable value harmless.

## A Kubernetes role that excludes Secrets

Kubernetes has a built-in `view` ClusterRole, but I prefer an explicit allowlist for an agent. Kubernetes RBAC is additive and does not have a simple "all resources except Secrets" rule. A wildcard resource rule is therefore too broad.

This role covers the resources I normally need for application debugging:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: hermes-observer
  namespace: qa
rules:
  - apiGroups: [""]
    resources:
      - pods
      - pods/status
      - pods/log
      - services
      - endpoints
      - events
      - persistentvolumeclaims
      - resourcequotas
      - limitranges
    verbs: ["get", "list", "watch"]

  - apiGroups: ["apps"]
    resources:
      - deployments
      - deployments/status
      - replicasets
      - replicasets/status
      - statefulsets
      - statefulsets/status
      - daemonsets
      - daemonsets/status
    verbs: ["get", "list", "watch"]

  - apiGroups: ["batch"]
    resources:
      - jobs
      - jobs/status
      - cronjobs
      - cronjobs/status
    verbs: ["get", "list", "watch"]

  - apiGroups: ["networking.k8s.io"]
    resources:
      - ingresses
      - ingresses/status
      - networkpolicies
    verbs: ["get", "list", "watch"]

  - apiGroups: ["autoscaling"]
    resources:
      - horizontalpodautoscalers
      - horizontalpodautoscalers/status
    verbs: ["get", "list", "watch"]

  - apiGroups: ["metrics.k8s.io"]
    resources:
      - pods
    verbs: ["get", "list"]
```

There is deliberately no `secrets` resource and no `create`, `update`, `patch`, or `delete` verb.

I use a namespaced `Role`, not a `ClusterRoleBinding`, because the agent does not need to see every team and system namespace. To cover both QA and production, I apply the same role separately in those two namespaces. That repetition is useful: access remains visible and easy to remove per environment.

## GCP and GKE setup

Create a dedicated service account. Do not reuse a developer identity or a CI deployment account.

```bash
PROJECT_ID="example-prod"
SERVICE_ACCOUNT="hermes-observer"
SERVICE_EMAIL="${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create "$SERVICE_ACCOUNT" \
  --project "$PROJECT_ID" \
  --display-name "Hermes read-only observer"
```

Grant enough access to discover and connect to GKE, plus logs and metrics:

```bash
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:${SERVICE_EMAIL}" \
  --role "roles/container.clusterViewer"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:${SERVICE_EMAIL}" \
  --role "roles/logging.viewer"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:${SERVICE_EMAIL}" \
  --role "roles/monitoring.viewer"
```

`roles/container.clusterViewer` can get and list clusters and connect to them. It is narrower than granting project-wide `roles/viewer` or GKE `roles/container.viewer`.

An administrator then binds the Kubernetes role to the service account in each approved namespace:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: hermes-observer
  namespace: qa
subjects:
  - kind: User
    name: hermes-observer@example-prod.iam.gserviceaccount.com
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: hermes-observer
  apiGroup: rbac.authorization.k8s.io
```

Repeat it for production only after the QA access behaves as expected.

### Authenticate without leaking a key

The better options are service account impersonation or Workload Identity Federation. They avoid leaving a long-lived private key on disk.

If the Hermes host already runs under an identity allowed to impersonate the observer account:

```bash
gcloud config set auth/impersonate_service_account \
  hermes-observer@example-prod.iam.gserviceaccount.com
```

If a JSON service account key is unavoidable, keep it outside the repository, restrict its file mode, and rotate it:

```bash
chmod 600 /secure/path/hermes-gcp-key.json

gcloud auth activate-service-account \
  hermes-observer@example-prod.iam.gserviceaccount.com \
  --key-file=/secure/path/hermes-gcp-key.json \
  --project=example-prod
```

Do not paste the JSON into a prompt, issue, shell transcript, or blog post.

Fetch a dedicated kubeconfig rather than overwriting a developer's default context:

```bash
export KUBECONFIG="$HOME/.kube/hermes-gke-readonly"

gcloud container clusters get-credentials example-cluster \
  --region europe-west1 \
  --project example-prod
```

A separate kubeconfig makes accidents less likely and makes it obvious which identity Hermes is using.

## AWS and EKS setup

On AWS I use a dedicated IAM role, preferably assumed through an EC2 instance profile, IAM Identity Center, or another short-lived credential flow. Static access keys are the fallback, not the first choice.

The cloud-side policy only needs to describe the EKS cluster and read the observability services used during debugging. A minimal starting point looks like this:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DiscoverEks",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ReadLogsAndMetrics",
      "Effect": "Allow",
      "Action": [
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents",
        "logs:FilterLogEvents",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    }
  ]
}
```

Some investigations also need `ec2:Describe*` actions to understand nodes, security groups, subnets, or load balancers. I add only the specific describe actions that the actual runbook needs.

For a modern EKS cluster using access entries, create an entry for the IAM role:

```bash
CLUSTER="example-cluster"
ROLE_ARN="arn:aws:iam::123456789012:role/HermesObserver"

aws eks create-access-entry \
  --cluster-name "$CLUSTER" \
  --principal-arn "$ROLE_ARN"
```

Associate the EKS view policy and restrict it to named namespaces:

```bash
aws eks associate-access-policy \
  --cluster-name "$CLUSTER" \
  --principal-arn "$ROLE_ARN" \
  --policy-arn \
    arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=namespace,namespaces=qa,production
```

AWS documents `AmazonEKSViewPolicy` as permission to view most Kubernetes resources. It includes workload status and pod logs, but Secrets are handled by separate EKS secret reader/admin policies. Do not associate either secret policy with the observer role.

The documented view policy does not include the `metrics.k8s.io` API. That means `kubectl top` may be denied even though normal workload reads succeed. I either use CloudWatch Container Insights for those numbers or map the access entry to a Kubernetes group and bind only the `metrics.k8s.io/pods` rule from the earlier Role. I do not widen the whole policy just to make one metrics command work.

Build the kubeconfig with the observer role:

```bash
export KUBECONFIG="$HOME/.kube/hermes-eks-readonly"

aws eks update-kubeconfig \
  --name example-cluster \
  --region eu-west-1 \
  --role-arn "$ROLE_ARN"
```

Older EKS clusters may still use the `aws-auth` ConfigMap and Kubernetes RoleBindings. Access entries are easier to audit, but the cluster authentication mode has to support them before these commands will work.

## Prove that read-only really means read-only

A role name is not evidence. I test the effective identity after authentication.

Start with the full rule summary:

```bash
kubectl auth can-i --list -n qa
```

Then test the operations that must fail:

```bash
kubectl auth can-i create pods -n qa
kubectl auth can-i patch deployments.apps -n qa
kubectl auth can-i delete pods -n qa
kubectl auth can-i create pods/exec -n qa
kubectl auth can-i get secrets -n qa
```

The expected answer is `no` for every command above.

Test the read path too:

```bash
kubectl auth can-i list pods -n qa
kubectl auth can-i get pods/log -n qa
kubectl get deployments -n qa
kubectl get events -n qa --sort-by=.lastTimestamp
kubectl top pods -n qa --containers
```

I also verify the cloud identity rather than trusting whichever profile happened to be active:

```bash
# GCP
gcloud auth list --filter=status:ACTIVE
gcloud config get-value project

# AWS
aws sts get-caller-identity
aws configure list
```

One detail caught me during setup: `kubectl` was reading a different default kubeconfig from the one created by the cloud CLI. The cloud authentication was correct, but `kubectl` still tried to connect to an unrelated local cluster. Setting `KUBECONFIG` explicitly removed that ambiguity.

## What Hermes can do with this access

Once the cloud identity, kubeconfig, namespace, and repository path are configured, the investigation flow becomes useful:

```text
1. Read pod status, events, logs, and resource usage.
2. Compare the failing workload with healthy replicas.
3. Inspect rollout history and deployment configuration.
4. Search the local application repository for matching errors.
5. Explain the likely failure and propose a fix.
6. Stop before any production change and ask a human.
```

That last step is part of the access model. Read-only credentials provide a technical boundary. A separate operating rule provides a behavioral boundary: sensitive reads and all side effects require approval.

For example, I allow routine checks of pod status, CPU, memory, events, and ordinary application logs. I require explicit permission before reading credentials, sensitive environment values, customer data, or unusually detailed logs that may contain private information.

## Anonymize what leaves the environment

The investigation output can leak information even when the commands are read-only.

Before putting output into a prompt, ticket, article, or public chat, I remove or replace:

- project, account, cluster, and organization IDs
- internal namespace and repository names
- service account emails and IAM role ARNs
- private domains, load balancer addresses, and IP addresses
- container registry paths
- customer IDs, email addresses, and request bodies
- tokens, cookies, authorization headers, and Secret values
- full stack traces when they contain private paths or payloads

I use obvious placeholders such as `example-prod`, `example-cluster`, `qa`, and `123456789012`. Plausible fake values are worse than obvious placeholders because someone may mistake them for real infrastructure.

The agent also does not need a copy of every command output forever. Keep logs for the minimum useful period, protect the Hermes host, audit cloud and Kubernetes access, and remove the identity when the debugging arrangement is no longer needed.

## The boundary I want

Giving an agent production access still deserves caution. Read-only access is not harmless: logs and metadata can reveal a lot, and Kubernetes Secrets are readable data if the role includes them.

But a dedicated identity with short-lived credentials, narrow cloud roles, namespace-scoped Kubernetes viewing, no Secret permission, and explicit approval for sensitive reads is a boundary I can reason about.

Hermes can investigate the live system and connect what it sees to the code. It cannot restart the pod to see if that helps. That is exactly where I want the line.

## References

- [Google Cloud: Authorize actions in GKE using RBAC](https://cloud.google.com/kubernetes-engine/docs/how-to/role-based-access-control)
- [Google Cloud: GKE roles and permissions](https://cloud.google.com/iam/docs/roles-permissions/container)
- [AWS: Review EKS access policy permissions](https://docs.aws.amazon.com/eks/latest/userguide/access-policy-permissions.html)
- [AWS: Create EKS access entries](https://docs.aws.amazon.com/eks/latest/userguide/creating-access-entries.html)
