# Kube-State-Metrics Installation & Configuration (Helm)

## 📌 Overview
Kube-State-Metrics (KSM) exposes Kubernetes cluster state metrics (Deployments, Pods, Nodes, etc.)  
It is often used with Prometheus & Grafana to monitor cluster health and workloads.

---

## 🔹 Prerequisites
- A running Kubernetes cluster (minikube, kind, or production)
- `kubectl` configured
- Helm installed and initialized
- Ingress Controller (e.g., NGINX Ingress)

---

## 🔹 Step 1: Add Helm Repo

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

---

## 🔹 Step 2: Create Custom Values File

Create a `values.yaml` file for customization:

```yaml
replicaCount: 1

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: true
  className: nginx   # or your ingress controller class
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  hosts:
    - host: ksm.example.com   # change to your domain
      paths:
        - path: /
          pathType: Prefix
  tls: []   # configure if you want SSL (with cert-manager, etc.)
```

---

## 🔹 Step 3: Install kube-state-metrics with Helm

```bash
helm install kube-state-metrics prometheus-community/kube-state-metrics -n kube-system -f values.yaml
```

If already installed, upgrade instead:

```bash
helm upgrade kube-state-metrics prometheus-community/kube-state-metrics -n kube-system -f values.yaml
```

Check that it’s running:

```bash
kubectl -n kube-system get pods | grep kube-state-metrics
```

---

## 🔹 Step 4: Test Access

- Update `/etc/hosts` if needed to map your domain:
  ```
  <INGRESS-CONTROLLER-IP>  ksm.example.com
  ```

- Open in browser:
  ```
  http://ksm.example.com/metrics
  ```

You should see Kubernetes object metrics such as `kube_pod_status_phase` or `kube_deployment_status_replicas`.

---

## 🔹 Step 5: Configure Prometheus Scraping

Update `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'kube-state-metrics'
    static_configs:
      - targets: ['ksm.example.com']
```

Reload Prometheus and confirm that the target is UP under **Status → Targets**.

---

## ✅ Conclusion
- Installed kube-state-metrics using Helm.
- Exposed metrics securely through Ingress at `ksm.example.com/metrics`.
- Integrated with Prometheus for scraping and Grafana dashboards.

---

## 🔗 References
- [Kube-State-Metrics GitHub](https://github.com/kubernetes/kube-state-metrics)
- [Helm Chart Repo](https://artifacthub.io/packages/helm/prometheus-community/kube-state-metrics)
