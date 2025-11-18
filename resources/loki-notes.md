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

An example Loki-distributed values file
```yaml
---
deploymentMode: Distributed

gateway:
  image:
    registry: quay.io
    repository: nginx/nginx-unprivileged
    tag: 1.24-alpine
  nginxConfig:
    resolver: "dns-default.openshift-dns.svc.cluster.local."


loki:
  auth_enabled: true
  commonConfig:
    path_prefix: /var/loki
  storage:
    type: s3
  schemaConfig:
    configs:
      - from: "2024-04-01"
        store: tsdb
        object_store: s3
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
  compactor:
    working_directory: /var/loki/compactor

podSecurityContext:
  runAsNonRoot: false
  allowPrivilegeEscalation: false

containerSecurityContext:
  runAsNonRoot: false
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true

test:
  enabled: false

sidecar:
  rules:
    enabled: false
  datasources:
    enabled: false


singleBinary:
  replicas: 0
backend:
  replicas: 0
read:
  replicas: 0
write:
  replicas: 0

bloomPlanner:
  replicas: 0
bloomBuilder:
  replicas: 0
bloomGateway:
  replicas: 0

lokiCanary:
  enabled: false

ruler:
  enabled: false

global:
  extraArgs:
    - "-log.level=debug"

gateway:
  service:
    type: LoadBalancer
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      memory: 256Mi

loki:
  commonConfig:
    replication_factor: 3
  storage:
    type: s3
    s3:
      region: us-east-1
  storage_config:
    aws:
      region: us-east-1
      s3forcepathstyle: false
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

  querier:
    max_concurrent: 8
  query_range:
    parallelise_shardable_queries: true

ingester:
  replicas: 3
  autoscaling:
    enabled: true
  zoneAwareReplication:
    enabled: true
  maxUnavailable: 1
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi
  persistence:
    enabled: true
    size: 10Gi
  affinity: {}
  podAntiAffinity:
    soft: {}
    hard: {}

querier:
  replicas: 3
  autoscaling:
    enabled: true
  maxUnavailable: 1
  resources:
    requests:
      cpu: 300m
      memory: 512Mi
    limits:
      memory: 1Gi
  affinity: {}

queryFrontend:
  replicas: 2
  maxUnavailable: 1
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      memory: 512Mi

queryScheduler:
  replicas: 2
  maxUnavailable: 1
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      memory: 512Mi

distributor:
  replicas: 5
  autoscaling:
    enabled: true
    minReplicas: 5
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
  maxUnavailable: 1
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      memory: 2Gi
  affinity: {}

compactor:
  replicas: 1
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      memory: 1Gi

indexGateway:
  replicas: 2
  maxUnavailable: 0
  resources:
    requests:
      cpu: 300m
      memory: 512Mi
    limits:
      memory: 1Gi
  affinity: {}

chunksCache:
  enabled: true
  replicas: 1

resultsCache:
  enabled: true
  replicas: 1

memcached:
  enabled: true

memcachedResults:
  enabled: true

memcachedChunks:
  enabled: true

memcachedFrontend:
  enabled: true

memcachedIndexQueries:
  enabled: true

memcachedIndexWrites:
  enabled: true

minio:
  enabled: false

memcachedExporter:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      memory: 128Mi
```

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

So increas the grpc message sizes as the following:
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

Nginx controller would need to have GRPC support added to the Service
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
