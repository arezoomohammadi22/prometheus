# Prometheus + Alertmanager + Flask Discord Proxy — API & Testing Cheat Sheet

This README contains:

- How to manually test your **Flask proxy** with `curl`
- Common **Alertmanager v2 API** endpoints (and examples)
- Common **Prometheus v1 API** endpoints (and examples)

---

## 1) Manual test: Flask proxy (local)

Your Flask proxy endpoint:

- **URL:** `http://localhost:5000/webhook`
- **Method:** `POST`
- **Content-Type:** `application/json`
- **Expected JSON shape:** a top-level object with an `alerts` array

### 1.1 FIRING test (matches your Flask template)

> This is the exact request you used; it includes `status`, `labels`, `annotations.summary`, and `startsAt`.

```bash
curl -X POST http://localhost:5000/webhook   -H "Content-Type: application/json"   -d '{
    "alerts": [
      {
        "status": "firing",
        "labels": {
          "alertname": "FlaskProxyTest",
          "instance": "manual-curl"
        },
        "annotations": {
          "summary": "This is a FIRING test sent directly via curl"
        },
        "startsAt": "2025-12-30T10:40:00Z"
      }
    ]
  }'
```

### 1.2 RESOLVED test (also matches your Flask template)

```bash
curl -X POST http://localhost:5000/webhook   -H "Content-Type: application/json"   -d '{
    "alerts": [
      {
        "status": "resolved",
        "labels": {
          "alertname": "FlaskProxyTest",
          "instance": "manual-curl"
        },
        "annotations": {
          "summary": "This is a RESOLVED test sent directly via curl"
        },
        "startsAt": "2025-12-30T10:40:00Z",
        "endsAt": "2025-12-30T10:45:00Z"
      }
    ]
  }'
```

### 1.3 Multiple alerts in one request

```bash
curl -X POST http://localhost:5000/webhook   -H "Content-Type: application/json"   -d '{
    "alerts": [
      {
        "status": "firing",
        "labels": { "alertname": "CPUHigh", "instance": "srv-01" },
        "annotations": { "summary": "CPU usage is high" },
        "startsAt": "2025-12-30T10:40:00Z"
      },
      {
        "status": "resolved",
        "labels": { "alertname": "DiskRecovered", "instance": "srv-02" },
        "annotations": { "summary": "Disk usage back to normal" },
        "startsAt": "2025-12-30T10:20:00Z",
        "endsAt": "2025-12-30T10:41:00Z"
      }
    ]
  }'
```

> Note: Discord has a **2000 character** limit per message if you send everything in `"content"`. If you group many alerts, you may need to **chunk** messages in your Flask proxy.

---

## 2) Alertmanager REST API (v2)

Default base URL (compose host port mapping example):

- **Base:** `http://localhost:9093`
- **API prefix:** `/api/v2`

### 2.1 Health / status

- `GET /api/v2/status`

```bash
curl -sS http://localhost:9093/api/v2/status | jq
```

### 2.2 List active alerts

- `GET /api/v2/alerts`

```bash
curl -sS "http://localhost:9093/api/v2/alerts" | jq
```

Common filters (optional):
- `?active=true|false`
- `?silenced=true|false`
- `?inhibited=true|false`
- `?unprocessed=true|false`
- `?receiver=<name>`

Example:
```bash
curl -sS "http://localhost:9093/api/v2/alerts?active=true" | jq
```

### 2.3 Send alerts manually (API test injection)

- `POST /api/v2/alerts`

**FIRING now:**
```bash
curl -X POST http://localhost:9093/api/v2/alerts   -H "Content-Type: application/json"   -d '[
    {
      "labels": {
        "alertname": "ManualAPITest",
        "instance": "test-host",
        "severity": "warning"
      },
      "annotations": {
        "summary": "Manual alert sent to Alertmanager API"
      },
      "startsAt": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"
    }
  ]'
```

**Auto-resolve (Linux date):**
```bash
curl -X POST http://localhost:9093/api/v2/alerts   -H "Content-Type: application/json"   -d '[
    {
      "labels": {
        "alertname": "ManualAPITestAutoResolve",
        "instance": "test-host",
        "severity": "info"
      },
      "annotations": {
        "summary": "This alert should resolve soon"
      },
      "startsAt": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",
      "endsAt": "'"$(date -u -d "+1 minute" +%Y-%m-%dT%H:%M:%SZ)"'"
    }
  ]'
```

**Auto-resolve (macOS date):**
```bash
curl -X POST http://localhost:9093/api/v2/alerts   -H "Content-Type: application/json"   -d '[
    {
      "labels": {
        "alertname": "ManualAPITestAutoResolve",
        "instance": "test-host",
        "severity": "info"
      },
      "annotations": {
        "summary": "This alert should resolve soon"
      },
      "startsAt": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",
      "endsAt": "'"$(date -u -v+1M +%Y-%m-%dT%H:%M:%SZ)"'"
    }
  ]'
```

### 2.4 Silences

- `GET /api/v2/silences` (list)
- `POST /api/v2/silences` (create)
- `GET /api/v2/silence/{silenceId}` (read one)
- `DELETE /api/v2/silence/{silenceId}` (expire/delete)

List:
```bash
curl -sS http://localhost:9093/api/v2/silences | jq
```

Create example silence (mute alertname=ManualAPITest for 1 hour):
```bash
curl -X POST http://localhost:9093/api/v2/silences   -H "Content-Type: application/json"   -d '{
    "matchers": [
      { "name": "alertname", "value": "ManualAPITest", "isRegex": false }
    ],
    "startsAt": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",
    "endsAt": "'"$(date -u -d "+1 hour" +%Y-%m-%dT%H:%M:%SZ)"'",
    "createdBy": "manual",
    "comment": "temporary silence for testing"
  }'
```

### 2.5 Receivers

- `GET /api/v2/receivers`

```bash
curl -sS http://localhost:9093/api/v2/receivers | jq
```

---

## 3) Prometheus REST API (v1)

Default base URL (compose host port mapping example):

- **Base:** `http://localhost:9090`
- **API prefix:** `/api/v1`

### 3.1 Instant query

- `GET /api/v1/query`

```bash
curl -sS "http://localhost:9090/api/v1/query?query=up" | jq
```

### 3.2 Range query

- `GET /api/v1/query_range`

Example (last 10 minutes, 15s step) — Linux:
```bash
END="$(date -u +%s)"
START="$((END-600))"
curl -sS "http://localhost:9090/api/v1/query_range?query=up&start=${START}&end=${END}&step=15" | jq
```

### 3.3 Alerts (from rules evaluation)

- `GET /api/v1/alerts`

```bash
curl -sS http://localhost:9090/api/v1/alerts | jq
```

### 3.4 Rules (recording + alerting rules loaded)

- `GET /api/v1/rules`

```bash
curl -sS http://localhost:9090/api/v1/rules | jq
```

### 3.5 Targets (scrape targets + health)

- `GET /api/v1/targets`

```bash
curl -sS http://localhost:9090/api/v1/targets | jq
```

### 3.6 Labels & series discovery

- `GET /api/v1/labels`
- `GET /api/v1/label/<label_name>/values`
- `GET /api/v1/series`
- `GET /api/v1/metadata`

Examples:
```bash
curl -sS http://localhost:9090/api/v1/labels | jq
curl -sS http://localhost:9090/api/v1/label/__name__/values | jq
curl -sS "http://localhost:9090/api/v1/series?match[]=up" | jq
curl -sS http://localhost:9090/api/v1/metadata | jq
```

### 3.7 Config reload (optional)

Prometheus supports:

- `POST /-/reload`

But it works only if Prometheus is started with:
- `--web.enable-lifecycle`

Command:
```bash
curl -X POST http://localhost:9090/-/reload
```

---

## 4) Quick troubleshooting tips

### 4.1 Discord message too long
Discord `"content"` must be **<= 2000 chars**. Reduce Alertmanager grouping or chunk messages in Flask.

### 4.2 Verify Flask proxy receives requests
```bash
docker logs -f discord-webhook-proxy
```

### 4.3 Verify Alertmanager can reach Flask proxy (inside compose network)
```bash
docker exec -it alertmanager sh -lc "wget -qO- --header='Content-Type: application/json' --post-data='{"alerts":[]}' http://discord-webhook-proxy:5000/webhook || true"
```

---

