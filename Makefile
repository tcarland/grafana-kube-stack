
clean:
	( rm -f mimir/base/secrets.env \
	  alloy/base/config.alloy \
	  loki/base/loki-values.yaml \
	  ingress/nginx/base/nginx-values.yaml \
	  ingress/istio/istio-operator.yaml \
	  prometheus/base/prom-values.yaml \
	  grafana/base/secrets.env \
	  tempo/base/tempo-values.yaml \
	  loki/ingress/istio/base/*.crt \
	  loki/ingress/istio/base/*.key \
	  loki/ingress/istio/base/params.env \
	  loki/ingress/nginx/base/*.crt \
	  loki/ingress/nginx/base/*.key \
	  loki/ingress/nginx/base/params.env \
	  tempo/ingress/istio/base/*.crt \
	  tempo/ingress/istio/base/*.key \
	  tempo/ingress/istio/base/params.env \
	  tempo/ingress/nginx/base/*.crt \
	  tempo/ingress/nginx/base/*.key \
	  tempo/ingress/nginx/base/params.env \
	  grafana/ingress/istio/base/*.crt \
	  grafana/ingress/istio/base/*.key \
	  grafana/ingress/istio/base/params.env \
	  grafana/ingress/nginx/base/*.crt \
	  grafana/ingress/nginx/base/*.key \
	  grafana/ingress/nginx/base/params.env \
	  prometheus/ingress/istio/base/*.crt \
	  prometheus/ingress/istio/base/*.key \
	  prometheus/ingress/istio/base/params.env \
	  prometheus/ingress/istio/base/prometheus-virtualservice.yaml \
	  prometheus/ingress/nginx/base/*.crt \
	  prometheus/ingress/nginx/base/*.key \
	  prometheus/ingress/nginx/base/params.env \
	  prometheus/ingress/nginx/base/auth )


clean-charts:
	( rm -rf mimir/base/charts \
	  loki/base/charts \
	  prometheus/base/charts \
	  tempo/base/charts \
	  alloy/base/charts )

distclean: clean-charts clean
