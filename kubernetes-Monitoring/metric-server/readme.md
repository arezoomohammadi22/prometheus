# Metrics Server Installation & Configuration

## 📌 Overview
Metrics Server is a cluster-wide aggregator of resource usage data in Kubernetes.  
It collects CPU and memory usage from each Node and Pod through the Kubelet and exposes it via the Kubernetes API.  
These metrics are used by:
- `kubectl top`
- Horizontal Pod Autoscaler (HPA)
- Other monitoring tools

---

## 🔹 Prerequisites
- A running Kubernetes cluster (Minikube, Kind, or Production cluster)
- `kubectl` installed and configured
- Cluster-admin privileges

---

## 🔹 Step 1: Install Metrics Server

Apply the official components manifest:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Verify installation:

```bash
kubectl -n kube-system get pods | grep metrics-server
```

Test with:

```bash
kubectl top nodes
kubectl top pods -A
```

---

## 🔹 Step 2: Configure Metrics Server (for self-managed clusters)

If you are running on bare-metal, Minikube, or clusters with self-signed certificates,  
you need to update the Metrics Server Deployment with additional flags.

Edit the Deployment:

```bash
kubectl -n kube-system edit deployment metrics-server
```

Add these arguments under the container spec:

```yaml
spec:
  containers:
  - name: metrics-server
    args:
      - --kubelet-insecure-tls
      - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
```

Save & exit. Then restart the deployment:

```bash
kubectl -n kube-system rollout restart deployment metrics-server
```

---

## 🔹 Step 3: Verify Functionality

Check metrics API:

```bash
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes | jq .
```

Run `kubectl top` commands again to confirm:

```bash
kubectl top nodes
kubectl top pods -A
```

---

## 🔹 Step 4: Integration with Prometheus

To scrape Metrics Server with Prometheus, add this to `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'metrics-server'
    scheme: https
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets: ['metrics-server.kube-system.svc.cluster.local:443']
```

Reload Prometheus or restart the deployment.

---

## ✅ Conclusion
- Metrics Server provides live resource usage metrics (CPU/Memory).
- It does **not** store long-term data (use Prometheus for history).
- Essential for `kubectl top` and HPA functionality.

---

## 🔗 References
- [Metrics Server GitHub](https://github.com/kubernetes-sigs/metrics-server)
- [Kubernetes Docs](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/)
