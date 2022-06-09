
export VAULT_KEYSTORE_PATH="${HOME}/.obb"
cp -rp ${VAULT_KEYSTORE_PATH}/vault/vaultkeys ${VAULT_KEYSTORE_PATH}/vault/vaultkeys.backup
echo "[ INFO ] Restoring vault snapshot...!"
kubectl cp backup.snap consul-0:/tmp/
kubectl exec -it consul-0 -- /bin/sh -c "consul snapshot restore /tmp/backup.snap"
VAULT_PODS=$(kubectl -n openbluebridge get pods -l app.kubernetes.io/name=vault --no-headers | awk '{print $1}')
for VAULT_POD in ${VAULT_PODS}
do
if [ ! -z ${VAULT_POD} ];
then
kubectl -n openbluebridge exec -it ${VAULT_POD} -- vault operator unseal ${UNSEAL_KEY}
fi
kubectl delete secret vautl-token-keys 3>&1 1>/dev/null 2>&3-
kubectl -n openbluebridge create secret generic vautl-token-keys --from-literal=unseal_key="${UNSEAL_KEY}" 3>&1 1>/dev/null 2>&3-

