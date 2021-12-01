#!/bin/bash
sudo docker restart kube-apiserver kube-proxy kube-controller-manager kubelet kube-scheduler ; sleep "120"
/usr/local/bin/oauth2IpUpdate.sh > /dev/null ; sleep "10"
kubectl delete po -l app=configuration-ui

