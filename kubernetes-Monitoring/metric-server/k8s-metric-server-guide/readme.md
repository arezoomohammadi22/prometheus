# 📊 Kubernetes Metric Server — Overview & Verification Guide

## 🧩 What Is Metric Server?

**Metric Server** is a lightweight aggregator that collects **CPU and Memory usage** from all Pods and Nodes in a Kubernetes cluster.  
It provides **real-time metrics** via the Kubernetes API so that internal components (like **Horizontal Pod Autoscaler** and `kubectl top`) can make scaling or monitoring decisions.

> ⚠️ Metric Server does **not store historical data**.  
> It only provides *live metrics* — for monitoring history, use **Prometheus**.

---

## 🧠 Key Points

| Feature | Description |
|----------|-------------|
| Source of data | Kubelet `/stats/summary` endpoint |
| Aggregation interval | ~15 seconds |
| Data retention | Only in-memory (no database) |
| Used by | `kubectl top`, HPA, VPA, Kubernetes Dashboard |
| Format | Kubernetes API (not Prometheus metrics) |
| Endpoint | `/apis/metrics.k8s.io/v1beta1/` |
| Historical data | ❌ No |
| External monitoring (Grafana/Prometheus) | ❌ Not used directly |

---

## ⚙️ Verify Metric Server Installation

You can verify that Metric Server is installed and responding via API calls.

### 1️⃣ Using `kubectl`

```bash
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" | jq
```

If you get a JSON response with CPU and memory usage, Metric Server is working.

---

### 2️⃣ Using `kubectl top`

```bash
kubectl top nodes
kubectl top pods -A
```

You should see live CPU and memory usage per node or pod.

---

## 🔍 Direct API Check with `curl`

If you want to check the raw API directly (for debugging):

```bash
curl -k https://<K8S_API_SERVER>:6443/apis/metrics.k8s.io/v1beta1/pods
```

You might see an error like:

```json
{
  "status": "Failure",
  "reason": "Forbidden",
  "message": "pods.metrics.k8s.io is forbidden: User \"system:anonymous\" cannot list resource \"pods\"..."
}
```

That means the endpoint exists ✅ (Metric Server is running)  
but your request was **unauthenticated** ❌.

---

## 🔐 Authentication Options

### ✅ Option 1 — Use `kubectl proxy` (Recommended for testing)

Start a local authenticated proxy:
```bash
kubectl proxy --port=8001
```

Then access Metric Server safely:
```bash
curl http://127.0.0.1:8001/apis/metrics.k8s.io/v1beta1/pods
curl http://127.0.0.1:8001/apis/metrics.k8s.io/v1beta1/nodes
```

✅ No token required — `kubectl proxy` authenticates using your current kubeconfig.

---

### ✅ Option 2 — Use ServiceAccount Token (for external access)

If an external system (like Prometheus) needs to read metrics, create a ServiceAccount with read permission:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metrics-reader
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metrics-reader-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:aggregated-metrics-reader
subjects:
  - kind: ServiceAccount
    name: metrics-reader
    namespace: kube-system
```

Then get its token:
```bash
TOKEN=$(kubectl -n kube-system get secret $(kubectl -n kube-system get sa metrics-reader -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode)
```

Use the token with `curl`:

```bash
curl -k -H "Authorization: Bearer $TOKEN" https://<K8S_API_SERVER>:6443/apis/metrics.k8s.io/v1beta1/pods
```

✅ You’ll receive valid JSON metrics.

---

## 🧠 Troubleshooting Tips

| Symptom | Likely Cause | Fix |
|----------|---------------|-----|
| `Error from server (NotFound)` | Metric Server not installed | Deploy via Helm or manifest |
| `Forbidden: system:anonymous` | No authentication | Use `kubectl proxy` or token |
| `No metrics returned` | Metrics API not aggregated yet | Wait 1–2 minutes after pod startup |
| HPA not scaling | Metric Server missing or misconfigured | Check with `kubectl get apiservices` |

---

## 📘 References

- [Kubernetes Metric Server GitHub](https://github.com/kubernetes-sigs/metrics-server)
- [Kubernetes Autoscaling Docs](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Accessing the Kubernetes API Securely](https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-api/)

---

✅ **Summary**

> Metric Server is **not for monitoring or Grafana**.  
> It’s for **real-time internal metrics** that Kubernetes uses for **autoscaling** and **`kubectl top`** commands.
