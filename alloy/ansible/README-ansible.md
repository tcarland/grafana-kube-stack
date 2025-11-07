

Grafana does provide an Ansible Collection, but installs alloy as root.
The provided playbook creates an *alloy* user and attaches it to the 
required groups instead.

Note that the Prometheus and Loki endpoints would need to be updated 
accordingly or provided at playbook execution.
```sh
ansible-playbook -i "hostA,hostB,host[10:15]," \
  -e "loki_endpoint=https://loki.domain.com \
  prometheus_endpoint=https://prometheus.domain.com" alloy.yml
```
