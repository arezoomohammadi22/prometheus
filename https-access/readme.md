# Securing Prometheus with NGINX Reverse Proxy and Self-Signed SSL

This guide explains how to secure your Prometheus UI with a self-signed SSL certificate and expose it behind an **NGINX reverse proxy**.

---

## 1. Generate Self-Signed SSL Certificate

Run the following commands on your server:

```bash
# Generate a private key
openssl genrsa -out /etc/ssl/private/prometheus.key 2048

# Generate a certificate signing request (CSR)
openssl req -new -key /etc/ssl/private/prometheus.key -out /etc/ssl/private/prometheus.csr

# Generate a self-signed certificate valid for 1 year
openssl x509 -req -days 365 -in /etc/ssl/private/prometheus.csr -signkey /etc/ssl/private/prometheus.key -out /etc/ssl/certs/prometheus.crt
```

Now you have:
- `/etc/ssl/private/prometheus.key` → Private key
- `/etc/ssl/certs/prometheus.crt` → Self-signed certificate

---

## 2. Install and Configure NGINX

Install NGINX (if not already installed):

```bash
sudo apt update && sudo apt install -y nginx
```

Create a new site config for Prometheus:

```bash
sudo nano /etc/nginx/sites-available/prometheus
```

Add the following:

```nginx
server {
    listen 80;
    server_name prometheus.example.com;

    # Redirect HTTP to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name prometheus.example.com;

    ssl_certificate     /etc/ssl/certs/prometheus.crt;
    ssl_certificate_key /etc/ssl/private/prometheus.key;

    location / {
        proxy_pass http://localhost:9090/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/prometheus /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## 3. Update Prometheus (if needed)

Run Prometheus normally (no need to enable TLS inside Prometheus since NGINX handles it):

```bash
./prometheus --config.file=prometheus.yml
```

Prometheus should now be available at:

```
https://prometheus.example.com
```

*(Browser will show a warning because the certificate is self-signed — you can accept the risk or add the cert to your trusted store.)*

---

## 4. (Optional) Add Basic Authentication

If you also want authentication, install `apache2-utils` and create a password file:

```bash
sudo apt install -y apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd admin
```

Then update your NGINX config:

```nginx
location / {
    auth_basic "Prometheus Login";
    auth_basic_user_file /etc/nginx/.htpasswd;

    proxy_pass http://localhost:9090/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

Reload NGINX:

```bash
sudo systemctl reload nginx
```

Now Prometheus is available at:

```
https://prometheus.example.com
```

with **basic auth** enabled.

---

✅ You now have Prometheus running securely behind NGINX with a self-signed SSL certificate.

