# Docker Container Monitoring with cAdvisor

This guide helps you monitor your Docker containers using **cAdvisor**.

------------------------------------------------------------------------

## 1. Prerequisites

-   Docker & Docker Compose installed on your host
-   Internet access to pull container images

------------------------------------------------------------------------

## 2. cAdvisor Service

Here is the configuration for `docker-compose.yml`:

``` yaml
version: "3"
services:
  cadvisor:
    image: google/cadvisor:latest
    container_name: cadvisor
    restart: always
    privileged: true
    ports:
      - "8080:8080"
    volumes:
      - "/:/rootfs:ro"
      - "/var/run:/var/run:rw"
      - "/sys:/sys:ro"
      - "/var/lib/docker/:/var/lib/docker:ro"
      - "/dev/disk/:/dev/disk:ro"
```

Run cAdvisor:

``` bash
docker-compose up -d cadvisor
```

Access cAdvisor at: <http://localhost:8080>

------------------------------------------------------------------------

## 3. Grafana Dashboard

If you already have Grafana running in your environment, you can import
a pre-built dashboard for container monitoring.

-   Dashboard ID: **395**
-   Title: **Main overview**
-   URL: <https://grafana.com/grafana/dashboards/395-main-overview/>

### Steps to Import

1.  Go to Grafana → **Dashboards → Import**
2.  Enter the dashboard ID: `395`
3.  Select your Prometheus data source
4.  Click **Import**

------------------------------------------------------------------------

## 4. Stop/Remove

``` bash
docker-compose down
```

To clean up volumes:

``` bash
docker-compose down -v
```
