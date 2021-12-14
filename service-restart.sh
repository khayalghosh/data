#!/bin/bash
sudo docker restart kube-apiserver kube-proxy kube-controller-manager kubelet kube-scheduler ; sleep "120"
kubectl delete po -l app=configuration-ui

