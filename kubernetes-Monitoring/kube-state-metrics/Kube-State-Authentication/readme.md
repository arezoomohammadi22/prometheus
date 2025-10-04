# Kube-State-Metrics with Basic Authentication (Ingress)

## 📌 Overview
Kube-State-Metrics (KSM) exposes detailed information about Kubernetes objects.  
If you expose it through an Ingress, you should secure it with **authentication** to prevent unauthorized access.

This guide shows how to add **HTTP Basic Authentication** to KSM using **NGINX Ingress Controller**.

---

## 🔹 Prerequisites
- Kubernetes cluster with Ingress Controller (NGINX Ingress)
- `kubectl` access
- `kube-state-metrics` installed (via Helm or manifests)
- `htpasswd` utility (for generating credentials)

---

## 🔹 Step 1: Create Username/Password

Generate credentials file with `htpasswd`:

```bash
# Install apache2-utils if not available
sudo apt-get install apache2-utils

# Create password file (username = admin)
htpasswd -c auth admin
```

You will be prompted to enter a password.  
This creates a file named `auth` with encoded credentials.

---

## 🔹 Step 2: Create Kubernetes Secret

Store the `auth` file in Kubernetes as a secret:

```bash
kubectl create secret generic kube-state-metrics-auth -n kube-system   --from-file=auth
```

---

## 🔹 Step 3: Configure Ingress with Basic Auth

Update your Helm `values.yaml` or Ingress manifest with the following annotations:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: kube-state-metrics-auth
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
  hosts:
    - host: ksm.example.com    # change to your domain
      paths:
        - path: /
          pathType: Prefix
```

Apply changes (if using Helm):

```bash
helm upgrade kube-state-metrics prometheus-community/kube-state-metrics   -n kube-system -f values.yaml
```

---

## 🔹 Step 4: Test Access

- Update `/etc/hosts` if needed to point `ksm.example.com` to your Ingress controller IP.
- Access metrics:
  ```
  http://ksm.example.com/metrics
  ```
- You should be prompted for a username and password.  
- Enter `admin` and the password you set earlier.

---

## 🔹 Step 5: Configure Prometheus Scraping (with Auth)

If Prometheus scrapes through this Ingress, you must add the username and password in `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'kube-state-metrics'
    basic_auth:
      username: "admin"
      password: "YOUR_PASSWORD"
    static_configs:
      - targets: ['ksm.example.com']
```

Reload Prometheus, and the target should show as UP.

---

## ✅ Conclusion
- Kube-State-Metrics is now protected with Basic Authentication.  
- Only users/services with the correct credentials can access `/metrics`.  
- This setup is simple and effective for small/medium environments.  
- For production-grade security, consider OAuth2 proxy or mTLS.

---

## 🔗 References
- [NGINX Ingress Annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#authentication)
- [Kube-State-Metrics](https://github.com/kubernetes/kube-state-metrics)
