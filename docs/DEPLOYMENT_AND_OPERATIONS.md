# Production Deployment and Operations Guide

## 1. Operating Prerequisites

Coffer is engineered for production deployment across Linux (Ubuntu 22.04+, RHEL 9+) and macOS systems.

### Minimum System Specifications:
- **CPU**: 4 vCPU cores (x86_64 or ARM64 / Apple Silicon).
- **RAM**: 8 GB memory.
- **Disk**: NVMe SSD with low-latency `fsync` support for Write-Ahead Logging.
- **Runtimes**: Ballerina 2201.14.1+, Clang/LLVM 15+, Python 3.10+.

---

## 2. Linux Kernel Tuning

For high-throughput settlement workloads processing thousands of network connections:

```ini
# /etc/sysctl.d/99-coffer.conf
fs.file-max = 2097152
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
```

Apply immediately:
```bash
sudo sysctl --system
```

---

## 3. Systemd Service Unit

```ini
# /etc/systemd/system/coffer.service
[Unit]
Description=Coffer Distributed Payment Orchestration Engine
After=network.target

[Service]
Type=simple
User=coffer
Group=coffer
WorkingDirectory=/opt/coffer
ExecStart=/usr/bin/bal run
Restart=always
RestartSec=5s
LimitNOFILE=65536
LimitNPROC=32768
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

---

## 4. Observability and Prometheus Integration

Scrape metrics continuously from `http://127.0.0.1:8990/metrics`:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: "coffer_payment_orchestrator"
    scrape_interval: 5s
    static_configs:
      - targets: ["127.0.0.1:8990"]
```

### Critical Production Alert Rules:
- **CircuitBreakerOpen**: Alert if `coffer_circuit_breaker_open == 1` for more than 60 seconds.
- **HighQuarantineRate**: Alert if `rate(coffer_quarantined_total[5m]) > 10`.
- **LatencyDegradation**: Alert if `coffer_transfer_latency_us{quantile="0.99"} > 5000000` (p99 exceeds 5 seconds).
