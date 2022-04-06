#!/bin/bash
/usr/local/bin/oauth2IpUpdate.sh
sudo docker restart kube-apiserver kube-proxy kube-controller-manager kubelet kube-scheduler
sleep 180
kubectl delete pod -l app=authorization-v2
while [ $(kubectl -n openbluebridge get pods -l app=authorization-v2 --no-headers -o custom-columns=READY-true:status.containerStatuses[*].ready | grep -c "true") -le 0 ];
do
   echo "[ WARN ] Waiting for authorization-v2 to be ready..."
   sleep 30
done
sleep 60
#kubectl delete pod -l app=oauth2-proxy
kubectl rollout restart deploy oauth2-proxy
kubectl rollout restart deploy configuration-ui
kubectl delete pod -l app=connector
# Restart iotech xrt services when IP changed.
sudo systemctl restart xrt