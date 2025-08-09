#!/bin/bash
UNSEAL_KEY="$2"
SERVER_TYPE="$1"
CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cat << EOF > migrate.hcl
storage_source "file" {
address = "[::]:8201"
path    = "/vault/data"
}
storage_destination "consul" {
  path = "vault"
  address = "http://consul.<placeholder>.svc.cluster.local:8500"
}

cluster_addr = "[::]:8201"
EOF

if [[ $SERVER_TYPE == "dest" ]]
    VAULT_PODS=$(kubectl -n <test> get pods -l app.kubernetes.io/name=vault --no-headers | awk '{print $1}')
    for VAULT_POD in ${VAULT_PODS}
    do
    if [ ! -z ${VAULT_POD} ];
    then
        kubectl -n <namesapce> exec -it ${VAULT_POD} -- vault operator unseal ${UNSEAL_KEY}
    fi
    kubectl delete secret vautl-token-keys 3>&1 1>/dev/null 2>&3-
    kubectl -n <namesapce> create secret generic vautl-token-keys --from-literal=unseal_key="${UNSEAL_KEY}" 3>&1 1>/dev/null 2>&3-
elif [[ $SERVER_TYPE == "src"]]
    kubectl cp migrate.hcl vault-0:/tmp
    kubectl exec -it vault-0 -- /bin/sh -c "vault operator migrate -config=/tmp/migrate.hcl"
    kubectl exec -it consul-0 -- /bin/sh -c "consul snapshot save backup.snap"
    kubectl cp consul-0:/backup.snap "${CURDIR}/backup.snap"
fi
rm migrate.hcl
