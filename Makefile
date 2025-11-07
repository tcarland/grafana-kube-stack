
clean:
	( rm -f mimir/base/secrets.env \
	  alloy/base/config.alloy \
	  loki/base/loki-values.yaml \
	  prometheus/base/prom-values.yaml \
	  tempo/base/tempo-values.yaml \
	  loki/istio/base/*.crt \
	  loki/istio/base/*.key \
	  loki/istio/base/params.env \
	  loki/nginx/base/*.crt \
	  loki/nginx/base/*.key \
	  loki/nginx/base/params.env \
	  prometheus/istio/base/*.crt \
	  prometheus/istio/base/*.key \
	  prometheus/istio/base/params.env \
	  prometheus/nginx/base/*.crt \
	  prometheus/nginx/base/*.key \
	  prometheus/nginx/base/params.env )

clean-charts:
	( rm -rf mimir/base/charts \
	  loki/base/charts \
	  prometheus/base/charts \
	  tempo/base/charts \
	  alloy/base/charts )

distclean: clean-charts clean
