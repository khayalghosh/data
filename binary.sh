#!/bin/bash
## Kindly place this script in user Home directory
read -p "Please Enter the name of Directory using which OBB is installed:" directory_name

binary_name= ${directory_name} | awk '{$1=$1};1'

cat <<< '
---
- name: Ansible Copy Vault files to remote dir
  hosts: openbluebridge_kubernetes_nodes
  tasks:
    - name: Install jq
      become: true
      copy:
        src: /usr/bin/jq
        dest: /usr/bin/jq
        mode: 755
    - name: Install Kubectl
      become: true
      copy:
        src: /usr/bin/kubectl
        dest: /usr/bin/kubectl
    - name: Copying VaultKeys
      become: true
      copy:
        src: "{{ lookup('env', 'HOME') }}/.obb"
        dest: "{{ lookup('env', 'HOME')}}"
    - name: Copying Kube Config
      become: true
      copy:
        src: "{{ lookup('env', 'HOME') }}/.kube/config"
        dest: "{{ lookup('env', 'HOME')}}/.kube/"
    - name: Copying install binary
      become: true
      copy:
        src: "{{ lookup('env', 'HOME') }}/{{ copyDir }}"
        dest: "{{ lookup('env', 'HOME') }}/{{ copyDir }}"' > ${binary_name}/k8s-cluster/ansible/roles/bootstrap/copyVaultFiles.yml

ansible-playbook -T 60 -i ${binary_name}/k8s-cluster/ansible/hosts  ${binary_name}/k8s-cluster/ansible/roles/bootstrap/copyVaultFiles.yml --extra-vars="copyDir=${binary_name}"

echo "Completed the Required changes"
