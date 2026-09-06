---
layout: post
title:  "GKE's Two Health Check Systems and the Premature 502"
description: "GKE deployments can pass every readiness probe and still serve 502s, because Kubernetes probes and the Cloud Load Balancer run two separate health checks."
date: 2025-06-01
categories: [DevOps]
tags: [gcp, kubernetes, networking, debugging]
---
<audio controls preload="metadata" src="/assets/audio/gcp-502-two-systems-summary.ogg">
  Your browser does not support the audio element.
</audio>

You deploy a new version to Google Kubernetes Engine. The CI/CD pipeline is green, `kubectl get pods` shows every pod `Running`, and the deployment is successful by every visible measure. You open the application's URL and get a **502 Bad Gateway**.

After a few refreshes, the error disappears and the application loads fine. Readiness probes were configured. They should have kept traffic away from the pods until they were ready. Traffic arrived early anyway.

The cause is a fact that isn't obvious from the tooling: GKE runs two separate health check systems, and they aren't synchronized by default.

## Two Worlds, Two Health Checks

The fundamental misunderstanding arises because the Kubernetes health checks (liveness/readiness probes) and the Google Cloud Load Balancer's health check operate in different domains and serve different purposes.

  * **Kubernetes Probes (Internal World):** These live *inside* your GKE cluster. They determine a pod's health from the perspective of Kubernetes itself. Is the pod running correctly? Is it ready to accept *internal* traffic from other services?
  * **Cloud Load Balancer Health Check (External World):** This lives *outside* your cluster, within the Google Cloud network. It determines a backend's health from the perspective of the global load balancer. Is this group of pods (represented by a Network Endpoint Group or NEG) ready to receive *external* user traffic?

Here’s a high-level view of how they are separated:

When these two systems are not perfectly aligned, the Load Balancer can declare the backend "healthy" and send traffic *before* Kubernetes considers all the individual pods truly ready to serve, leading to the 502.

## How Each Component Fits Together

Tracing the path of a request from the user to the pod shows where each piece sits.

### 1. Kubernetes Liveness & Readiness Probes

These are the health checks you define in your pod's specification.

  * **Readiness Probe:** Tells the Kubernetes Service when a pod is ready to be added to the pool of service endpoints. If it fails, the Service removes the pod's IP address, stopping *internal cluster traffic* from reaching it.
  * **Liveness Probe:** Tells the Kubelet if a pod needs to be restarted. If it fails, the pod is killed and a new one is created.

**Key takeaway:** Probes manage a pod's lifecycle and internal network availability *within the Kubernetes cluster*.

### 2. Kubernetes Service (`ClusterIP`)

When you create a Service of type `ClusterIP`, you create a stable, internal IP address that other pods can use to access the pods matched by the Service's selector. The Service uses the results of the **readiness probe** to maintain its list of healthy endpoints.

### 3. Kubernetes Ingress

The Ingress object is your request for external access. You define rules for how traffic from a specific host or path should be routed to a Kubernetes Service. In GKE, the GKE Ingress controller watches for these objects and automatically provisions a powerful **Google Cloud External HTTPS Load Balancer**.

### 4. The Google Cloud Load Balancer

This is not a single entity. The GKE Ingress controller creates a collection of GCP resources:

  * **Forwarding Rule:** The public IP address that receives user traffic.
  * **Target Proxy:** Terminates the user's HTTPS session.
  * **URL Map:** Routes the request to the correct backend based on the host and path (e.g., `api.example.com/users`).
  * **Backend Service:** Manages a collection of backends, and this is where the Load Balancer's Health Check is configured.

### 5. The Load Balancer Health Check

This is the heart of the problem. When GKE provisions the load balancer, it automatically creates a **GCP Health Check** and attaches it to the Backend Service. This health check runs from Google's global infrastructure and pings your pods directly on their IP addresses (via a Network Endpoint Group - NEG).

**If this health check passes, the Load Balancer considers the backend healthy and will send user traffic to it.** It does not know or care about your Kubernetes readiness probe's status.

## The Race Condition That Causes the 502

Putting the pieces together shows the race condition directly.

1.  **Deployment:** You deploy your application. New pods start up.
2.  **Pod Startup:** Your application inside the pod takes time to initialize (e.g., connect to a database, load caches). During this time, its readiness probe is failing.
3.  **Two Checks Begin:** Both the K8s readiness probe and the GCP LB health check start pinging the new pods.
4.  **The Race:** The default GCP health check created by the Ingress controller is often very simple. It might just check if a TCP connection can be made on the port. This check can pass **very quickly**, sometimes seconds before your application is truly initialized and its more sophisticated readiness probe passes.
5.  **The Result:**
      * **GCP LB Health Check passes.** The Load Balancer declares the backend "HEALTHY".
      * The Load Balancer immediately starts sending user traffic to the new pod's IP.
      * The pod receives the traffic but its internal application isn't ready. It can't handle the request and returns an error.
      * The Ingress proxy sees this application error and returns a **502 Bad Gateway** to the user.
6.  **The Recovery:** A few seconds later, the Kubernetes readiness probe finally passes. The application is now fully initialized. New requests that arrive are handled correctly. The 502s stop.

## Troubleshooting Tips

When you see a 502, don't just look at your pods. Check the state of the Load Balancer.

1.  **Find your Backend Service:** Get the name of the backend service associated with your Ingress.

    ```bash
    kubectl describe ingress <your-ingress-name>
    # Look for an annotation like "ingress.gcp.kubernetes.io/backends"
    # It will contain the name of the Backend Service.
    ```

2.  **Check the Load Balancer's view of backend health:** Use `gcloud` to ask the Load Balancer directly if it thinks its backends are healthy.

    ```bash
    gcloud compute backend-services get-health <backend-service-name> --global
    ```

    This command will show you the health status of each endpoint (pod) from the **Load Balancer's perspective**. If it says `HEALTHY` here while you're getting 502s, you've confirmed the race condition.

3.  **Describe the GCP Health Check:** See exactly what the Load Balancer is checking.

    ```bash
    # First, get the health check name from the backend service
    gcloud compute backend-services describe <backend-service-name> --global | grep healthChecks

    # Then, describe the health check itself
    gcloud compute health-checks describe <health-check-name> --global
    ```

    This will reveal the port, path, interval, and thresholds the LB is using. You will often find it's a generic, and too optimistic, check.

## Aligning the Two Systems with `BackendConfig`

The official GKE solution is to use a `BackendConfig` Custom Resource Definition (CRD). This allows you to customize the GCP-specific settings for your backend, including the health check.

By creating a `BackendConfig`, you can force the Load Balancer to use health check parameters that are identical or closely aligned with your Kubernetes readiness probe.

Here’s how to do it:

1.  **Create a `BackendConfig` YAML file:**

    ```yaml
    # backend-config.yaml
    apiVersion: cloud.google.com/v1
    kind: BackendConfig
    metadata:
      name: my-app-backend-config
    spec:
      healthCheck:
        checkIntervalSec: 10
        timeoutSec: 5
        healthyThreshold: 1
        unhealthyThreshold: 3
        type: HTTP
        requestPath: /healthz  # <-- Use the same path as your readiness probe!
        port: 8080             # <-- Use the same port as your readiness probe!
    ```

2.  **Associate the `BackendConfig` with your Kubernetes Service:**
    You do this by adding an annotation to your Service manifest. Note that the service port must also be named.

    ```yaml
    # service.yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: my-app-service
      annotations:
        cloud.google.com/backend-config: '{"ports": {"8080":"my-app-backend-config"}}'
    spec:
      ports:
      - name: 8080  # <-- Port name must match the key in the annotation
        port: 8080
        protocol: TCP
        targetPort: 8080
      selector:
        app: my-app
      type: NodePort # Ingress requires NodePort or LoadBalancer type service
    ```

3.  **Apply both files:**

    ```bash
    kubectl apply -f backend-config.yaml
    kubectl apply -f service.yaml
    ```

Now, when the GKE Ingress controller creates the Load Balancer, it will see the `BackendConfig` and apply your custom health check parameters. Because the Load Balancer is now checking the exact same `/healthz` endpoint as your readiness probe, it cannot become healthy until the application itself reports that it is ready. The race condition is eliminated.

A 502 on GKE right after deployment is rarely a sign the application is broken. It's a symptom of two independent health-check layers: the external Cloud Load Balancer and the internal Kubernetes Service. `BackendConfig` closes that gap by making the load balancer check the same endpoint your readiness probe does, so traffic only flows once the application is actually ready.
