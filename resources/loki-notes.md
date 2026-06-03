Grafana Loki Notes
==================

Some notes discovered during deployment testing.


## Open File Handles

A full LGTM stack can create a ton of open file handles on 
nodes with components installed. While many examples provide 
settings for increasing the limits, they are often hard 
values.  

Consider that an open handle requires 1k of memory by the 
kernel and commonly we set the max to 10% of the system memory.
Typically this is sufficient, but note the value would change 
based on system memory.
```
tenpercent   = (TOTAL_SYSTEM_MEMORY_GB * 0.1) * (1024^3)
fs.file-max  = tenpercent / 1024
```

An example Loki-distributed values file can be pulled from the 
kustomize or found at the Chart [Repo](https://github.com/grafana-community/helm-charts/blob/loki-15.0.1/charts/loki/values.yaml)

Sample Config snippet.
```yaml
  limits_config:
      retention_period: 744h  # 31 days retention
      ingestion_rate_mb: 100
      ingestion_burst_size_mb: 300
      ingestion_rate_strategy: "local"
      max_streams_per_user: 0
      max_line_size: 2097152
      per_stream_rate_limit: 100M
      per_stream_rate_limit_burst: 400M
      reject_old_samples: false
      reject_old_samples_max_age: 168h
      discover_service_name: []
      discover_log_levels: false
      volume_enabled: true
      max_global_streams_per_user: 75000
      max_entries_limit_per_query: 100000
      increment_duplicate_timestamp: true
      allow_structured_metadata: true
  runtimeConfig:
    configs:
      log_stream_creation: true
      log_push_request: true
      log_push_request_streams: true
      log_duplicate_stream_info: true
  ingester:
    chunk_target_size: 8388608        # 8MB
    chunk_idle_period: 5m
    max_chunk_age: 2h
    chunk_encoding: snappy            # Compress data (reduces S3 transfer size)
    chunk_retain_period: 1h           # Keep chunks in memory after flush
    flush_op_timeout: 10m             # Add timeout for S3 operations


## GPRC size issues

Resolved by adding debug log level for Loki components as the following:

Extra debug logging output for Loki components in the Loki Helm chart:
```yaml
runtimeConfig:
  configs:
    kubearchive:
      log-push-request: true
      log-push-request-streams: true
      log-stream-creation: false
      log-duplicate-stream-info: true
```

And then we were able to see the exact error messages, like:
```
level=debug ts=2025-09-30T15:25:53.687936029Z caller=http.go:108 org_id=kubearchive msg=“push request failed” code=500 err=“rpc error: code = ResourceExhausted desc = grpc: received message larger than max (5257394 vs. 4194304)”
```

So increase the grpc message sizes as the following:
```yaml
server:
  grpc_server_max_recv_msg_size: 15728640 # 15MB
  grpc_server_max_send_msg_size: 15728640
ingester_client:
  grpc_client_config:
    max_recv_msg_size: 15728640 # 15MB
    max_send_msg_size: 15728640 # 15MB
query_scheduler:
  grpc_client_config:
    max_recv_msg_size: 15728640 # 15MB
    max_send_msg_size: 15728640 # 15MB
```

Nginx (**deprecated**) controller would need to have GRPC support added to 
the Service manifest.
```yaml
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  type: LoadBalancer
  ports:
    - name: https
      port: 443
      targetPort: 443
    - name: grpc
      port: 4317
      targetPort: 443 
```
