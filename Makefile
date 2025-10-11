

clean: distclean


distclean:
	( rm -f mimir/base/secrets.env \
	  loki/base/loki-values.yaml \
	  prometheus/base/prom-values.yaml \
	  tempo/base/tempo-values.yaml \
	  prometheus/istio/base/*.crt \
	  prometheus/istio/base/*.key \
	  prometheus/istio/base/params.env \
	  prometheus/nginx/base/*.crt \
	  prometheus/nginx/base/*.key \
	  prometheus/nginx/base/params.env )
