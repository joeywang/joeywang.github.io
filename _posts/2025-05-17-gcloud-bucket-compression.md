---
layout: post
title: "Boost Your Website Speed: Enabling Gzip/Brotli Compression with Google Cloud CDN"
date: 2022-05-17
tags: ["google cloud", "cdn", "compression"]
---

## Boost Your Website Speed: Enabling Gzip/Brotli Compression with Google Cloud CDN

In today's fast-paced digital world, website speed isn't just a nicety – it's a necessity. Faster loading times lead to better user experience, improved SEO rankings, and reduced bounce rates. One of the most effective ways to achieve this is by compressing your web content.

When serving content through Google Cloud CDN, you have powerful tools at your disposal to ensure your static assets are delivered to users in the smallest possible size. This article will guide you through enabling Gzip and Brotli compression for your Google Cloud CDN setup, covering step-by-step commands and essential best practices.

### Why Compression Matters

Before diving into the "how," let's briefly touch on the "why."

  * **Reduced Bandwidth:** Compressed files are smaller, meaning less data needs to be transferred from the server to the client. This reduces your egress costs from Google Cloud and saves users' data.
  * **Faster Load Times:** Smaller files download quicker, leading to a noticeable improvement in page load speed for your users.
  * **Improved User Experience:** A faster website means happier users, lower abandonment rates, and better engagement.
  * **SEO Benefits:** Search engines, including Google, factor page speed into their ranking algorithms.

Cloud CDN intelligently handles compression, preferring **Brotli** over **Gzip** when supported by the client, as Brotli generally offers better compression ratios for various content types.

### Understanding Cloud CDN Compression Modes

Google Cloud CDN offers a `compressionMode` setting on its backend services and backend buckets. This setting dictates how the CDN handles compressible content.

  * **`DISABLED` (Default):** If `compressionMode` is not explicitly set, or if it's set to `DISABLED`, Cloud CDN will *not* automatically compress eligible responses. It will serve the content as it receives it from your origin.
  * **`AUTOMATIC`:** This is the recommended setting. When `AUTOMATIC` is enabled, Cloud CDN will dynamically compress eligible responses using Brotli or Gzip, based on the client's `Accept-Encoding` header and the content's MIME type. It will then cache the compressed versions.

**Eligibility for Automatic Compression:**

For Cloud CDN to automatically compress content:

  * The response size must be between 1 KiB and 10 MiB.
  * The `Content-Type` must be a compressible type (e.g., `text/html`, `application/json`, `text/css`, `application/javascript`). Image, audio, and video formats are typically already compressed and are not re-compressed.
  * The response must not already have a `Content-Encoding` header.
  * The response must not have `Cache-Control: no-transform`.

### Step-by-Step Guide to Enabling Compression

Let's walk through the process of enabling and confirming compression.

#### Step 1: Identify Your Cloud CDN Origin

First, determine if your Cloud CDN is serving content from a **Backend Service** (e.g., connected to Compute Engine VMs, GKE, or Cloud Run) or a **Backend Bucket** (serving directly from Google Cloud Storage).

#### Step 2: Confirm Current Compression Mode (Optional, but Recommended)

It's a good practice to check the current state before making changes. If `compressionMode` isn't shown in the output, it defaults to `DISABLED`.

**For a Backend Service:**

```bash
gcloud compute backend-services describe YOUR_BACKEND_SERVICE_NAME --global
```

*(Replace `YOUR_BACKEND_SERVICE_NAME` with your actual service name. Use `--global` for global load balancers or `--region=YOUR_REGION` for regional ones.)*

**For a Backend Bucket:**

```bash
gcloud compute backend-buckets describe YOUR_BACKEND_BUCKET_NAME
```

*(Replace `YOUR_BACKEND_BUCKET_NAME` with your actual bucket name.)*

Look for the `compressionMode` field in the output. If it's missing, or explicitly states `DISABLED`, you'll need to enable it.

#### Step 3: Enable Automatic Compression

Now, let's update your backend to enable dynamic compression.

**For a Backend Service:**

```bash
gcloud compute backend-services update YOUR_BACKEND_SERVICE_NAME --compression-mode=AUTOMATIC --global
```

**For a Backend Bucket:**

```bash
gcloud compute backend-buckets update YOUR_BACKEND_BUCKET_NAME --compression-mode=AUTOMATIC
```

After executing the command, you should see output confirming the update.

#### Step 4: Invalidate Cloud CDN Cache

Changes to CDN configuration typically propagate within a few minutes (1-5 minutes). However, the CDN edge caches might still hold the *uncompressed* versions of your files from before the change. To ensure users immediately receive compressed content, you must invalidate the cache.

**To Invalidate All Content for a URL Map:**

```bash
gcloud compute url-maps invalidate-cdn-cache YOUR_URL_MAP_NAME --path "/*"
```

*(Replace `YOUR_URL_MAP_NAME` with the URL map associated with your HTTP(S) Load Balancer that uses this backend.)*

**To Invalidate Specific Paths (more granular):**

```bash
gcloud compute url-maps invalidate-cdn-cache YOUR_URL_MAP_NAME --path "/static/style.css,/js/main.js"
```

Cache invalidation usually takes another 5-10 minutes to propagate globally.

#### Step 5: Confirm Compression is Working

This is the most crucial step – verifying that your content is indeed being compressed and served by Cloud CDN.

**Method 1: Using Browser Developer Tools**

1.  Open your website in a web browser (e.g., Chrome, Firefox).
2.  Open Developer Tools (usually `F12` or `Ctrl+Shift+I` / `Cmd+Option+I`).
3.  Navigate to the "Network" tab.
4.  Refresh the page (`Ctrl+R` or `Cmd+R`).
5.  Find a compressible asset (like a `.css` or `.js` file, or your main HTML document).
6.  Click on the asset to view its details.
7.  In the "Headers" tab, look for:
      * **`Content-Encoding: gzip`** or **`Content-Encoding: br`**: This confirms successful compression.
      * **`Via: 1.1 google`**: Confirms the request went through Google Cloud CDN.
      * **`Age: [number]`**: A non-zero value indicates the asset is served from CDN cache.
8.  In the Network tab's overview, compare the "Size" (uncompressed size) and "Transferred" (compressed size). "Transferred" should be significantly smaller for compressed assets.

**Method 2: Using `curl` (Command Line)**

`curl` allows you to explicitly request compressed content and inspect headers.

```bash
curl -v -H "Accept-Encoding: gzip, deflate, br" https://your-domain.com/path/to/your/asset.css
```

*(Replace `https://your-domain.com/path/to/your/asset.css` with a URL to a compressible asset on your site.)*

In the output, you should see `Content-Encoding: gzip` or `Content-Encoding: br` among the response headers.

```
< HTTP/1.1 200 OK
< date: Fri, 27 Jun 2025 12:00:00 GMT
< expires: Fri, 27 Jun 2025 12:30:00 GMT
< cache-control: public, max-age=1800
< content-type: text/css
< content-encoding: br         # <--- Success!
< vary: Accept-Encoding
< server: Google Frontend
< via: 1.1 google              # <--- Served by Cloud CDN
<
```

### Best Practices

  * **Prioritize `AUTOMATIC` Compression:** For most use cases, let Cloud CDN handle dynamic compression. It's intelligent, handles Brotli, and simplifies your workflow (you don't need to pre-compress in your build pipeline).
  * **Set Appropriate Cache-Control Headers:** Ensure your GCS objects (if using Backend Buckets) or backend responses include proper `Cache-Control` headers (e.g., `Cache-Control: public, max-age=3600`) to maximize CDN caching effectiveness.
  * **Monitor Performance:** Keep an eye on your website's performance metrics (e.g., Core Web Vitals, page load times) before and after implementing compression to quantify the improvements. Google Cloud's Cloud Monitoring can help track CDN metrics like "Bytes served (total)" and "Bytes from cache."
  * **Test Thoroughly:** Always test changes in a staging or development environment before applying them to production.
  * **Avoid Double Compression:** Do not pre-compress files (e.g., setting `Content-Encoding: gzip` metadata on GCS objects) *and* also enable `AUTOMATIC` compression on Cloud CDN for the same content. Cloud CDN will respect an existing `Content-Encoding` header and won't re-compress, but it's best to let one system handle it. If you choose to pre-compress, ensure the `Content-Encoding` header is correctly set on the GCS object.

By following these steps, you can significantly enhance your website's performance and provide a faster, more efficient experience for your users, leveraging the power of Google Cloud CDN.
