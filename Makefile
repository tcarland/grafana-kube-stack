
clean:
	( rm -f mimir/base/secrets.env \
	  alloy/base/config.alloy \
	  loki/base/loki-values.yaml \
	  ingress/nginx/base/nginx-values.yaml \
	  ingress/istio/istio-operator.yaml \
	  prometheus/base/prom-values.yaml \
	  prometheus/base/secrets.env \
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
	  prometheus/ingress/grafana/istio/base/*.crt \
	  prometheus/ingress/grafana/istio/base/*.key \
	  prometheus/ingress/grafana/istio/base/params.env \
	  prometheus/ingress/grafana/nginx/base/*.crt \
	  prometheus/ingress/grafana/nginx/base/*.key \
	  prometheus/ingress/grafana/nginx/base/params.env \
	  prometheus/ingress/prom/istio/base/*.crt \
	  prometheus/ingress/prom/istio/base/*.key \
	  prometheus/ingress/prom/istio/base/params.env \
	  prometheus/ingress/prom/istio/base/prometheus-virtualservice.yaml \
	  prometheus/ingress/prom/nginx/base/*.crt \
	  prometheus/ingress/prom/nginx/base/*.key \
	  prometheus/ingress/prom/nginx/base/params.env \
	  prometheus/ingress/prom/nginx/base/auth )


clean-charts:
	( rm -rf mimir/base/charts \
	  loki/base/charts \
	  prometheus/base/charts \
	  tempo/base/charts \
	  alloy/base/charts )

distclean: clean-charts clean
