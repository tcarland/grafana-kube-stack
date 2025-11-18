Notes for using Traefik Ingress
===============================

Traefik must be told to listen on port 4317 for Tempo grpc-otlp
```
valuesContent: |-
  additionalArguments:
    - "--entrypoints.websecure.address=:443"
    - "--entrypoints.grpcsecure.address=:4317"
    - "--entrypoints.grpcsecure.http2=true"
```

Those arguments should be added to the Traefik *Deployment* `command:`
Additionally the Traefix *Service* should be updated for the ports
```yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik
  namespace: kube-system
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: traefik
  ports:
    - name: websecure
      port: 443
      targetPort: websecure
      protocol: TCP
    - name: grpcsecure
      port: 4317
      targetPort: grpcsecure
      protocol: TCP
```

Basic *IngressRoute* for TLS Termination
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: web-https
  namespace: default
spec:
  entryPoints:
    - websecure
  tls:
    secretName: example-com-tls
  routes:
    - match: Host(`example.com`) && PathPrefix(`/web`)
      kind: Rule
      services:
        - name: web-service
          port: 443
```


Add Auth via Middleware
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: http-auth
  namespace: $(namespace)
spec:
  basicAuth:
    secret: auth-secret
```

and append to *IngressRoute*
```yaml
routes:
  - match: Host()
    middlewares:
      - name: http-auth
```

Unfortunately, the Match syntax does not define the rules as part of the 
IngressRoute API. This makes it so replacements via kustomize
or the patch must provide the complete match value, eg. "Host('host.domain')"
