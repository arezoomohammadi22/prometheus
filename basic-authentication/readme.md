# Secure Prometheus UI with NGINX and Basic Authentication

Prometheus does not provide authentication or TLS natively.  
To secure the Prometheus web UI, we put it **behind an NGINX reverse proxy** with Basic Authentication.

---

## Prerequisites

- A running Prometheus instance (default on port `9090`).
- NGINX installed (can be inside Docker or directly on the host).
- `apache2-utils` package (for `htpasswd`).

---

## Step 1: Install htpasswd Tool

On Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install apache2-utils -y
```

---

## Step 2: Create User Credentials

Create a password file at `/etc/nginx/.htpasswd`:

```bash
sudo htpasswd -c /etc/nginx/.htpasswd myuser
```

- Replace `myuser` with your preferred username.
- You will be prompted for a password.
- To add more users later (without overwriting), use:
  ```bash
  sudo htpasswd /etc/nginx/.htpasswd anotheruser
  ```

---

## Step 3: Configure NGINX Reverse Proxy

Edit your NGINX configuration (e.g. `/etc/nginx/sites-available/prometheus`):

```nginx
server {
    listen 80;

    server_name prometheus.example.com;

    location / {
        proxy_pass http://localhost:9090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;

        auth_basic "Restricted Access";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
```

- Replace `prometheus.example.com` with your domain.
- Ensure Prometheus is running on `localhost:9090`.

---

## Step 4: Enable and Reload NGINX

```bash
sudo ln -s /etc/nginx/sites-available/prometheus /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## Step 5: Test Access

1. Visit: `http://prometheus.example.com`
2. A login prompt should appear.
3. Enter the username and password created with `htpasswd`.

---

## Step 6: (Optional) Enable HTTPS

It is **strongly recommended** to secure the reverse proxy with HTTPS.

Using [Certbot](https://certbot.eff.org/):

```bash
sudo apt-get install certbot python3-certbot-nginx -y
sudo certbot --nginx -d prometheus.example.com
```

Now Prometheus will be available at:
```
https://prometheus.example.com
```

---

## Summary

- Prometheus does not support authentication natively.
- We added **Basic Authentication** using NGINX.
- Optionally, we enabled **HTTPS** with Certbot.

Your Prometheus UI is now protected! 🎉
