---
layout: post
title:  "Enabling Local HTTPS for Development and Debugging"
description: "Local HTTPS matters because browser APIs like Service Workers require a secure context, and this covers Caddy, Nginx with mkcert, Puma-dev, and Cert-Manager."
date:   2025-07-01 14:41:26 +0100
categories: [DevOps]
tags: [nginx, kubernetes, devops, security]
---

<audio controls preload="metadata" src="/assets/audio/local-https-summary.ogg">
  Your browser does not support the audio element.
</audio>

Developing and debugging web applications often requires mirroring production as closely as possible, and that includes HTTPS. HTTP works for basic local testing, but many browser features, APIs, and security behaviors require a secure context. This covers several tools for local HTTPS: Nginx, Caddy, Puma-dev, and a local Kubernetes environment with Cert-Manager.

-----

## Why Local HTTPS Matters

Beyond matching production, local HTTPS has concrete benefits:

  * **Secure-context APIs:** Geolocation, Service Workers, WebUSB, and the Payment Request API are restricted to secure contexts. Developing with HTTPS locally means these actually work.
  * **Mixed content:** when parts of an application are served over HTTP and others over HTTPS, browsers block the insecure content, causing broken functionality or visual glitches.
  * **Cookie security:** secure cookies (the `Secure` attribute) only get sent over HTTPS, so local HTTPS is the only way to test that path accurately.
  * **HSTS:** if production uses HSTS, browsers enforce HTTPS on all later connections. Developing over plain HTTP locally can produce unexpected redirects or errors.
  * **Realism:** testing under the same protocol as production surfaces redirect and certificate issues earlier.

-----

## Tools for Local HTTPS

### Caddy: Automatic HTTPS

Caddy is a modern, open-source web server known for automatic HTTPS, and it's easy to set up for local development.

**How it works:**

Caddy automatically provisions and manages TLS certificates for your local domains using its internal CA (Certificate Authority). The first time it does this, it'll typically prompt you to install its root certificate into your system's trust store. Once trusted, your browser will recognize certificates issued by Caddy as valid for your local domains.

**Setup:**

1.  **Install Caddy:**
    Refer to the official Caddy documentation for installation instructions specific to your operating system. For macOS, `brew install caddy` is common.

2.  **Create a Caddyfile:**
    Create a file named `Caddyfile` in your project root or a central location. Here's a basic example for a local application running on `localhost:3000`:

    ```caddyfile
    mylocalapp.test {
        tls internal
        reverse_proxy localhost:3000
    }
    ```

      * `mylocalapp.test`: This is your custom local domain. You'll need to configure your `hosts` file (or a local DNS resolver like `dnsmasq`) to point this domain to `127.0.0.1`.
      * `tls internal`: This tells Caddy to automatically manage self-signed certificates for this domain and try to install its CA into your system's trust store.
      * `reverse_proxy localhost:3000`: This forwards incoming HTTPS requests to your application running on `localhost:3000` (or whatever port your app uses).

3.  **Run Caddy:**
    Navigate to the directory containing your `Caddyfile` in your terminal and run:

    ```bash
    caddy run
    ```

    Caddy will prompt you to trust its root certificate. Accept it.

4.  **Access your App:**
    Now, you can access your application securely at `https://mylocalapp.test`.

**Advantages:**

  * **Simplicity:** Minimal configuration required for HTTPS.
  * **Automatic Certificate Management:** Caddy handles certificate generation, renewal, and trust store integration.
  * **HTTP/2 and HTTP/3 support:** Modern protocols out of the box.

-----

### Nginx with mkcert

Nginx is a powerful and widely used web server and reverse proxy. While it doesn't have Caddy's automatic HTTPS magic, you can easily pair it with a tool like **mkcert** to generate locally trusted certificates.

**How it works:**

**mkcert** is a simple tool that creates locally-trusted development certificates. It does this by creating its own local CA and installing it into your system's trust store. You then use these certificates with Nginx.

**Setup:**

1.  **Install mkcert:**
    Follow the installation instructions for mkcert. For macOS, `brew install mkcert` and `mkcert -install` are typical. This command will install a local CA into your system's trust store.

2.  **Generate Certificates with mkcert:**
    Navigate to your project directory or a dedicated certificates folder and generate certificates for your local domain:

    ```bash
    mkcert mylocalapp.test localhost 127.0.0.1
    ```

    This will create `mylocalapp.test+2.pem` (certificate) and `mylocalapp.test+2-key.pem` (private key) files.

3.  **Install Nginx:**
    Install Nginx according to your operating system's instructions.

4.  **Configure Nginx:**
    Create or modify your Nginx configuration file (e.g., `nginx.conf` or a separate site configuration in `sites-available`/`sites-enabled`).

    ```nginx
    server {
        listen 443 ssl;
        server_name mylocalapp.test;

        ssl_certificate /path/to/your/certs/mylocalapp.test+2.pem;
        ssl_certificate_key /path/to/your/certs/mylocalapp.test+2-key.pem;

        # Optional: Redirect HTTP to HTTPS
        listen 80;
        return 301 https://$host$request_uri;

        location / {
            proxy_pass http://localhost:3000; # Your application's HTTP address
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
    ```

    Replace `/path/to/your/certs/` with the actual path where you saved your mkcert files.

5.  **Update `hosts` file:**
    Add an entry to your `hosts` file (e.g., `/etc/hosts` on Linux/macOS, `C:\Windows\System32\drivers\etc\hosts` on Windows):

    ```
    127.0.0.1 mylocalapp.test
    ```

6.  **Restart Nginx:**

    ```bash
    sudo nginx -s reload # or appropriate command for your system
    ```

7.  **Access your App:**
    You should now be able to access your application securely at `https://mylocalapp.test`.

**Advantages:**

  * **Flexibility:** Highly configurable for complex setups.
  * **Performance:** Excellent performance for serving static files and reverse proxying.
  * **Widely Used:** Extensive community support and resources.

-----

### Puma-dev

For Rails developers, Puma-dev is a streamlined option for local HTTPS with custom domains.

**How it works:**

Puma-dev acts as a local DNS server and HTTP/HTTPS proxy. It automatically resolves `*.test` domains (or other configurable TLDs) to your local machine, starts your Rails applications on demand, and provides HTTPS with self-signed certificates that are automatically trusted.

**Setup:**

1.  **Install Puma-dev:**

    ```bash
    gem install puma # Ensure puma gem is installed in your app's Gemfile
    brew install puma/puma/puma-dev # For macOS
    sudo puma-dev -setup # Sets up necessary DNS and certificate configurations
    puma-dev -install # Installs puma-dev as a user agent
    ```

2.  **Link your Rails App:**
    Navigate to your Rails application's root directory and link it:

    ```bash
    puma-dev link -n myrailsapp
    ```

    This will create a symlink in `~/.puma-dev` (or wherever Puma-dev stores its linked apps).

3.  **Access your App:**
    Now, simply open your browser and navigate to `https://myrailsapp.test`. Puma-dev will automatically start your Rails application and serve it over HTTPS.

**Advantages:**

  * **Rails-centric:** Designed specifically for Ruby on Rails development.
  * **Zero Configuration:** Minimal setup for automatic app linking, custom domains, and HTTPS.
  * **On-Demand Starting:** Only starts your Rails app when accessed, saving resources.

-----

### Kubernetes Local Environment with Cert-Manager

For applications intended for Kubernetes, a local cluster (Minikube, Kind) with Cert-Manager gives the closest local match to production HTTPS.

**How it works:**

Cert-Manager is a native Kubernetes certificate management controller. It can issue certificates from various sources, including self-signed CAs, Vault, or public CAs like Let's Encrypt. For local development, you'll typically configure a `ClusterIssuer` or `Issuer` that uses a self-signed CA. Cert-Manager then watches `Certificate` resources and automatically provisions TLS secrets for your Ingresses.

**Setup (using Minikube and a self-signed Issuer):**

1.  **Set up a Local Kubernetes Cluster:**
    Install and start Minikube (or Kind):

    ```bash
    minikube start
    ```

2.  **Install Cert-Manager:**
    Install Cert-Manager using Helm or kubectl manifests. It's recommended to use Helm:

    ```bash
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version v1.14.x # Use the latest stable version
    ```

    Verify the installation: `kubectl get pods -n cert-manager`

3.  **Create a Self-Signed ClusterIssuer:**
    This defines a cluster-wide CA that Cert-Manager will use to sign your development certificates. Create `selfsigned-clusterissuer.yaml`:

    ```yaml
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: selfsigned-issuer
    spec:
      selfSigned: {}
    ```

    Apply it: `kubectl apply -f selfsigned-clusterissuer.yaml`

4.  **Create an Ingress and Certificate Resource:**
    Assuming you have a deployment and service for your application, you'll need an `Ingress` to expose it and a `Certificate` resource for Cert-Manager to manage its TLS.

    Example `my-app-ingress.yaml`:

    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: my-app-ingress
      annotations:
        nginx.ingress.kubernetes.io/rewrite-target: /
        cert-manager.io/cluster-issuer: selfsigned-issuer # Link to your ClusterIssuer
    spec:
      rules:
      - host: myapp.local.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service # Your application's service name
                port:
                  number: 80
      tls: # Enable TLS for this Ingress
      - hosts:
        - myapp.local.com
        secretName: my-app-tls-secret # Cert-Manager will create this secret
    ---
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: my-app-certificate
      namespace: default # Or your application's namespace
    spec:
      secretName: my-app-tls-secret
      dnsNames:
      - myapp.local.com
      issuerRef:
        name: selfsigned-issuer
        kind: ClusterIssuer
    ```

    Apply these resources: `kubectl apply -f my-app-ingress.yaml`

5.  **Install an Ingress Controller:**
    You'll need an Ingress Controller (e.g., Nginx Ingress Controller) to actually route traffic. For Minikube, you can enable it with:

    ```bash
    minikube addons enable ingress
    ```

6.  **Update `hosts` file:**
    Get the Minikube IP and add an entry to your `hosts` file:

    ```bash
    minikube ip
    # Example output: 192.168.49.2
    ```

    Add to your `hosts` file:

    ```
    192.168.49.2 myapp.local.com
    ```

7.  **Trust the Cert-Manager CA:**
    Cert-Manager will create a CA certificate for its self-signed issuer. You'll need to extract this and manually trust it in your operating system's trust store. The exact steps vary, but it typically involves:

      * Getting the CA certificate from a Kubernetes secret (look for `cert-manager-ca` or similar, usually in the `cert-manager` namespace).
      * Decoding the base64-encoded certificate.
      * Importing it into your system's trusted root certificates.

    Example (might vary):

    ```bash
    kubectl get secret -n cert-manager cert-manager-webhook-ca -o jsonpath='{.data.ca\.crt}' | base64 --decode > cert-manager-ca.crt
    ```

    Then, import `cert-manager-ca.crt` into your OS.

8.  **Access your App:**
    Now, you can access your application securely at `https://myapp.local.com`.

**Advantages:**

  * **Production Parity:** Closest to how HTTPS is managed in a production Kubernetes environment.
  * **Automated Certificate Lifecycle:** Cert-Manager handles issuance, renewal, and secret management.
  * **Scalable:** Ideal for complex microservice architectures.

-----

Caddy is the simplest option, Nginx with mkcert gives the most control, Puma-dev fits a Rails-only workflow, and Kubernetes with Cert-Manager is worth the setup only if you're already testing against a local cluster. Any of them beats debugging secure-context bugs for the first time in production.
