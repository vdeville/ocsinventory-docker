"""Gunicorn configuration for the OCS Inventory backend."""

import multiprocessing
import os

bind = "0.0.0.0:8000"

# Default: (2 * cores) + 1, overridable for small VMs.
workers = int(os.getenv("GUNICORN_WORKERS", (multiprocessing.cpu_count() * 2) + 1))
threads = int(os.getenv("GUNICORN_THREADS", 1))

# Agent inventories are zlib-compressed XML; allow time for inflate + parse.
timeout = int(os.getenv("GUNICORN_TIMEOUT", 120))
graceful_timeout = 30
keepalive = 5

# Recycle workers to bound memory growth.
max_requests = int(os.getenv("GUNICORN_MAX_REQUESTS", 1000))
max_requests_jitter = int(os.getenv("GUNICORN_MAX_REQUESTS_JITTER", 100))

# Logs to stdout/stderr for `docker logs`.
accesslog = "-"
errorlog = "-"
loglevel = os.getenv("GUNICORN_LOG_LEVEL", "info")

# Honor X-Forwarded-* from the edge nginx (trusted internal network).
forwarded_allow_ips = os.getenv("GUNICORN_FORWARDED_ALLOW_IPS", "*")
