#!/bin/bash
## Kindly place this script in user Home directory
read -p "Please Enter the name of Directory using which OBB is installed:" binary_name



echo 'env VAULT_CONFIG=true
VAULT_PODS=$(kubectl -n openbluebridge get pods -l app.kubernetes.io/name=vault --no-headers | awk '{print \$1}')
for VAULT_POD in ${VAULT_PODS}
do
        if [ ! -z ${VAULT_POD} ];
then
        export VAULT_KEYSTORE_PATH="${HOME}/.obb"
        export VAULT_TOKEN="$(cat ${VAULT_KEYSTORE_PATH}/vault/vaultkeys | jq -r '.root_token')"
        kubectl exec -it ${VAULT_POD}  -- sh -c "export VAULT_TOKEN=${VAULT_TOKEN} && vault write auth/kubernetes/config issuer=\"https://kubernetes.default.svc.cluster.local\" disable_iss_validation=\"true\" token_reviewer_jwt=\"\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)\" kubernetes_host=\"https://\$KUBERNETES_PORT_443_TCP_ADDR:443\" kubernetes_ca_cert=\"\$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)\""
fi
done' > ${binary_name}/k8s-cluster/ansible/roles/bootstrap/templates/vault-config.sh



cat << EOF > ${binary_name}/k8s-cluster/ansible/roles/bootstrap/copyVaultFiles.yml
---
- name: Ansible Copy Vault files to remote dir
  hosts: openbluebridge_kubernetes_nodes
  tasks:
    - name: Install Kubectl
      become: sudo
      copy:
        src: /usr/bin/kubectl
        dest: /usr/bin/kubectl
    - name: Copying VaultKeys
      copy:
        src: "{{ lookup('env', 'HOME') }}/.obb"
        dest: "{{ lookup('env', 'HOME')}}"
    - name: Copying Kube Config
      copy:
        src: "{{ lookup('env', 'HOME') }}/.kube/config"
        dest: "{{ lookup('env', 'HOME')}}/.kube/"
    - name: Copy Fault Config Script
      become: true
      copy:
        src: templates/vault-config.sh
        dest: /usr/bin/vault-config.sh
    - name: Config Vault
      shell: sh /usr/bin/vault-config.sh
    - name: Copying install binary
      copy:
        src: "{{ lookup('env', 'HOME') }}/{{ copyDir }}"
        dest: "{{ lookup('env', 'HOME') }}/{{ copyDir }}"
EOF

ansible-playbook -T 60 -i ${binary_name}/k8s-cluster/ansible/hosts ${binary_name}/k8s-cluster/ansible/roles/bootstrap/copyVaultFiles.yml --extra-vars="copyDir=${binary_name}"
