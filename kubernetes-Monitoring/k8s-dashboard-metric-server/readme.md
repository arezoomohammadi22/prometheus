# 🧭 Kubernetes Dashboard & Metric Server Setup Guide

## 📘 Overview

This guide explains how to **deploy and access the Kubernetes Dashboard** securely, 
create an **admin ServiceAccount**, and view **live CPU/Memory data** collected by the **Metric Server**.

All steps have been verified on **Kubernetes v1.24+**.

---

## 🚀 1. Create Admin Service Account and Token

Create a file named `dashboard-admin.yaml` and paste the following content:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: admin-user
    namespace: kubernetes-dashboard
---
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: "admin-user"
type: kubernetes.io/service-account-token
```

Apply the file:

```bash
kubectl apply -f dashboard-admin.yaml
```

---

## 🔑 2. Retrieve Dashboard Token

Get the token to log into the Dashboard:

```bash
kubectl -n kubernetes-dashboard get secret admin-user-token -o jsonpath="{.data.token}" | base64 --decode
```

Copy the output — this is your **login token**.

---

## 🌐 3. Access the Dashboard

Forward the Dashboard service to your local machine:

```bash
kubectl -n kubernetes-dashboard port-forward service/kubernetes-dashboard 10443:443 --address 0.0.0.0
```

Access the Dashboard in your browser:

```
https://<NODE-IP>:10443/
```

For example:

```
https://10.211.55.50:10443/
```

⚠️ Ignore the browser’s security warning (self-signed certificate).

Choose **Token** login, then paste the token from step 2.

---

## 📊 4. Enable and Verify Metric Server

Metric Server is required for live CPU and Memory usage data in both the Dashboard and `kubectl top` commands.

Install Metric Server (if not already installed):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Verify installation:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
```

Look for:
```
status:
  conditions:
  - type: Available
    status: "True"
```

---

## ⚙️ 5. View Metrics via CLI

### View Pod metrics
```bash
kubectl top pods -A
```

### View Node metrics
```bash
kubectl top nodes
```

### View raw Metric Server API data
```bash
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" | jq
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq
```

Example output:
```json
{
  "kind": "PodMetricsList",
  "items": [
    {
      "metadata": { "name": "nginx-7d9c6fbbd6-h7x8f" },
      "containers": [
        {
          "name": "nginx",
          "usage": { "cpu": "5m", "memory": "22Mi" }
        }
      ]
    }
  ]
}
```

---

## 🧭 6. View Metrics in the Dashboard

After Metric Server is running, open the Dashboard and navigate to:

- **Workloads → Pods** → see *CPU* and *Memory usage* columns  
- **Nodes** → see node-level CPU and memory graphs  

If metrics are missing, ensure Metric Server is healthy and accessible inside the cluster.

---

## 🧠 7. Summary

| Component | Purpose |
|------------|----------|
| Dashboard | Web UI for managing and viewing Kubernetes resources |
| ServiceAccount | Authenticates user sessions in Dashboard |
| Secret (Token) | Provides secure access for login |
| Metric Server | Provides live CPU/Memory usage data |
| `kubectl top` | CLI command to read the same metrics as Dashboard |

---

✅ **You’re done!**  
You now have:
- A fully working Kubernetes Dashboard accessible at `https://<NODE-IP>:10443`
- Admin-level token access
- Real-time resource metrics from Metric Server
