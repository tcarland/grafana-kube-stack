Alloy Ansible Playbook
======================

Grafana does provide an Ansible Collection, but installs *Alloy* as root.
The provided playbook creates an *alloy* user/group and attaches it to a
set of defined/provided groups to join for controlling permissions. 
```yaml
vars:
  alloy_groups:
    - adm
    - systemd-journal
```

Update the provided playbook *alloy.yaml* accordingly, or create 
a proper  Ansible *inventory* to define the groups as well as the typical 
variables described below. The playbook has been tested against 
*Ansible v5.3.0*

Passing lists via *extra-vars* requires passing all the vars 
as *json* making an inventory file more effective and maintainable.

Running the playbook without creating an inventory would require 
providing the service endpoints, tenant id, and agent credentials, 
though we can use our environment config to achieve this. 

The following assumes TLS is enabled for all exposed endpoints. Note 
that *Tempo* does not use a protocol designation for its endpoints.
```sh
envname=dev
source ../../env/${envname}/${envname}.env

ansible-playbook -i "hostA,hostB,host[10:15]," \
  -e "loki_endpoint=https://${LOKI_DOMAINNAME} \
      prometheus_endpoint=https://${PROMETHEUS_DOMAINNAME} \
      tempo_http_endpoint=${TEMPO_DOMAINNAME}:3200 \
      tempo_otlp_endpoint=${TEMPO_DOMAINNAME}:4317 \
      tenant_org_id=${GRAFANA_ENV} \
      agent_username=${AGENT_USERNAME} \
      agent_password=${AGENT_PASSWORD}" \
  alloy.yml
```
