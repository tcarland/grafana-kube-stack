
clean:
	( rm -f mimir/base/secrets.env \
	  alloy/base/config.alloy \
	  loki/base/loki-values.yaml \
	  ingress/nginx/base/nginx-values.yaml \
	  ingress/istio/istio-operator.yaml \
	  prometheus/base/prom-values.yaml \
	  tempo/base/tempo-values.yaml \
	  loki/istio/base/*.crt \
	  loki/istio/base/*.key \
	  loki/istio/base/params.env \
	  loki/nginx/base/*.crt \
	  loki/nginx/base/*.key \
	  loki/nginx/base/params.env \
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
