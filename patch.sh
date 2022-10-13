#!/bin/bash
## Kindly place this script in user Home directory
read -p "Please Enter the name of Directory using which OBB is installed:" binary_name


cat << EOF > ${binary_name}/k8s-cluster/ansible/roles/bootstrap/copyVaultFiles.yml
---
- name: Ansible Copy Vault files to remote dir
  hosts: openbluebridge_kubernetes_nodes
  tasks:
    - name: Copying install binary
      copy:
        src: "{{ lookup('env', 'HOME') }}/{{ copyDir }}"
        dest: "{{ lookup('env', 'HOME') }}/{{ copyDir }}"
    - name: Install Kubectl
      become: sudo
      copy:
        src: /usr/bin/kubectl
        dest: /usr/bin/kubectl
    - name: Install Helm
      become: yes
      copy:
        src: /usr/local/bin/helm
        dest: /usr/local/bin/helm
    - name: Copying VaultKeys
      copy:
        src: "{{ lookup('env', 'HOME') }}/.obb"
        dest: "{{ lookup('env', 'HOME')}}"
    - name: Copying Kube Config
      copy:
        src: "{{ lookup('env', 'HOME') }}/.kube/config"
        dest: "{{ lookup('env', 'HOME')}}/.kube/"
    - name: Replace IP
      shell: sed -r -i 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b'/"`hostname -I | cut -d' ' -f1 | tr -d '\n'`"/ "$HOME/.kube/config"
EOF

ansible-playbook -T 60 -i ${binary_name}/k8s-cluster/ansible/hosts ${binary_name}/k8s-cluster/ansible/roles/bootstrap/copyVaultFiles.yml --extra-vars="copyDir=${binary_name}"
