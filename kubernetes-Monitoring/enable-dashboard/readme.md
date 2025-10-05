# 🧭 Enabling Kubernetes Dashboard and Metric Server

## 📘 Overview

This guide walks you through **enabling the Kubernetes Dashboard**, creating an **admin user with token access**, and enabling the **Metric Server** so you can see live CPU and memory usage for pods and nodes.

All steps have been tested on **Kubernetes v1.24+**.

---

## 🚀 1. Install Kubernetes Dashboard

Deploy the official Dashboard manifests:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

Verify installation:

```bash
kubectl get pods -n kubernetes-dashboard
```

Expected output:

```
NAME                                    READY   STATUS    RESTARTS   AGE
kubernetes-dashboard-7f88c9d6c4-lbdrx   1/1     Running   0          1m
```

---

## 🧑‍💻 2. Create Admin User and Token

Create a file named `dashboard-admin.yaml`:

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

Apply it:

```bash
kubectl apply -f dashboard-admin.yaml
```

Get the login token:

```bash
kubectl -n kubernetes-dashboard get secret admin-user-token -o jsonpath="{.data.token}" | base64 --decode
```

Copy the output — it’s your **Dashboard login token**.

---

## 🌐 3. Access the Dashboard

Forward the service to your local machine:

```bash
kubectl -n kubernetes-dashboard port-forward service/kubernetes-dashboard 10443:443 --address 0.0.0.0
```

Then open your browser and go to:

```
https://<NODE-IP>:10443/
```

Example:

```
https://10.211.55.50:10443/
```

⚠️ Ignore the browser’s SSL warning (it uses a self-signed certificate).  
Select **Token** login and paste the token from step 2.

---

## 📊 4. Enable Metric Server

Metric Server provides live CPU and memory usage data for both Dashboard and `kubectl top` commands.

Install it:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Verify it’s working:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
```

Expected section:

```
status:
  conditions:
  - type: Available
    status: "True"
```

---

## ⚙️ 5. Check Metrics from CLI

### View all pod metrics

```bash
kubectl top pods -A
```

### View all node metrics

```bash
kubectl top nodes
```

### View raw Metric Server data

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

Once the Metric Server is running, open your Dashboard and navigate to:

- **Workloads → Pods** → view *CPU* and *Memory usage* columns  
- **Nodes** → view node-level CPU and memory usage graphs

If you don’t see any metrics, check that the Metric Server pod is healthy:

```bash
kubectl logs -n kube-system deploy/metrics-server
```

---

## 🧠 7. Summary

| Component | Purpose |
|------------|----------|
| Dashboard | Web UI for managing and viewing Kubernetes resources |
| ServiceAccount | Authenticates user sessions in Dashboard |
| Secret (Token) | Provides secure login credentials |
| Metric Server | Provides real-time CPU and Memory metrics |
| `kubectl top` | CLI command for the same live metrics |

---

✅ **You’re done!**  
You now have:
- A working **Kubernetes Dashboard** at `https://<NODE-IP>:10443`
- Secure **token-based login**
- **Live resource usage** from Metric Server

