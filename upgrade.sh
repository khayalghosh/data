#!/bin/bash
ENVFILE="$1"
SERVICENAME="$2"
#EXIT_FLAG=false
source "${ENVFILE}"

if [ -f "${HOME}/.obb/extraEnv" ];
then
  source "${HOME}/.obb/extraEnv"
fi

CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

DOMAIN_ACCESS="${cluster_domain_access_enabled}"
IS_DOMAIN_REGISTERED="${cluster_is_domain_registered}"
#### Flags Status
INGRESS_AUTH="${flags_ingress_auth_enabled}"
DEV_MODE="${flags_dev_mode_enabled}"
NODE_PORT="${flags_node_port_enabled}"
CLEAN_RABBIT="${flags_cleanrabbit}"
CLEAN_CONSUL="${flags_cleanconsul}"
CLEAN_ALL="${flags_cleanall}"
OPTIONAL_SERVICES="${optional_deploy}"
VAULT_STATUS="${flags_vault_enabled}"

ANSIBLE_DIR="${CURDIR}/../k8s-cluster/ansible"
ANSIBLE_HOSTFILE="${ANSIBLE_DIR}/hosts"

NODE_IPADDRESS="$(hostname -I | cut -d' ' -f1)"

OSFAMILY=$(uname -s | tr '[:upper:]' '[:lower:]')
[ "${OSFAMILY}" == "linux" ] && BASEDECODE="-d" || BASEDECODE="-D"
#export KUBECONFIG="${CURDIR}/../k8s-cluster/kube_config_rke-cluster.yml"
export KUBECONFIG="${HOME}/.kube/config"

if [ ! -z "${nodes_public_ip_addr}" ];
then
  [ "${nodes_public_ip_addr}" == "privateIpAddr" ] && K8S_API_SERVER_HOST="${cluster_domain_name}" || K8S_API_SERVER_HOST="${nodes_public_ip_addr}"
else
  K8S_API_SERVER_URL="$(kubectl config view -o jsonpath='{range .clusters[*]}{.cluster.server}{end}')"
  K8S_API_SERVER_HOST="$(echo ${K8S_API_SERVER_URL} | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')"
fi

#### Get node count for replicaset
REPLICAS=$(echo $(kubectl get nodes --no-headers | wc -l) | tr -s "[:space:]")

echo "[ INFO ] Please wait whilst updating the helm repository ...!"
helm repo update 3>&1 1>/dev/null 2>&3-

###############################################
# obb node id and version
kubectl create configmap openbluebridge-nodename --namespace=${cluster_namespace} --from-literal=OB_NODE_NAME=$(cat /etc/machine-id) -o yaml --dry-run=client | kubectl apply -f - 3>&1 1>/dev/null 2>&3-
kubectl create configmap openbluebridge-version --namespace=${cluster_namespace} --from-literal=OB_VERSION="${cluster_release_version}" -o yaml --dry-run=client | kubectl apply -f - 3>&1 1>/dev/null 2>&3-
###############################################

[[  $flags_node_port_enabled = true ]] && SERVICETYPE="NodePort" || SERVICETYPE="ClusterIP"

if [[ "${SERVICENAME}" && ( "${SERVICENAME}" != "all" ) ]];
then
  ###############################################
  for CORE_REL_NAME in ${core_services__ChartVersion[*]}
  do
    IFS=: read RELEASE_NAME CHART VERSION <<<"${CORE_REL_NAME}"
    if [[ "${RELEASE_NAME}" == "${SERVICENAME}" ]];
    then
      UPGRADE_RELEASE_NAME=${SERVICENAME};
      break;
    fi
  done

  if [ "${UPGRADE_RELEASE_NAME}" == "authorization-v2" ];
  then
    echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
    if [ ${DOMAIN_ACCESS} = true ];
    then
        helm secrets upgrade --install --wait --timeout 300s ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
        --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
        --set service.type=${SERVICETYPE} --set env.OB_OBBUri="https://${cluster_domain_name}" 3>&1 1>/dev/null 2>&3- 
    else
        helm secrets upgrade --install --wait --timeout 300s ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
        --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
        --set service.type=${SERVICETYPE} --set env.OB_OBBUri="https://${K8S_API_SERVER_HOST}" 3>&1 1>/dev/null 2>&3- 
    fi
    exit 0;
  elif [ "${UPGRADE_RELEASE_NAME}" == "assetmanagement" ];
  then 
    echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
    helm secrets upgrade --install --wait --timeout 300s ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
    --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
    --set ingress.oAuth=${INGRESS_AUTH} --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3- 
    exit 0;
  elif [ "${UPGRADE_RELEASE_NAME}" == "configuration-ui" ];
    then 
      echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
      #kubectl -n $cluster_namespace create configmap connector-version --from-literal version=$(cat ${CURDIR}/../config.yml| grep -i connector | tr -d ' ' | awk -F ":" {'print $(NF-1)":"$(NF)'}) -o yaml --dry-run=client | kubectl apply -f -
      kubectl -n $cluster_namespace create configmap connector-version \
      --from-literal factoryDeploy=false \
      --from-literal version=$(cat ${CURDIR}/../config.yml | grep -i connector | tr -d ' ' | awk -F ":" {'print $(NF-1)":"$(NF)'}) -o yaml --dry-run=client | kubectl apply -f -
      helm delete ${RELEASE_NAME} >> /dev/null 2>&1 
      helm secrets upgrade --install --wait --timeout 300s ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace "$cluster_namespace" \
      --set service.type=${SERVICETYPE} --set extraArgs.clusterApiServer="${cluster_api_server}" \
      --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
      --set ingress.oAuth=${INGRESS_AUTH} 3>&1 1>/dev/null 2>&3- 
      # --set extraArgs.hostIp="${K8S_API_SERVER_HOST}" --set extraArgs.clusterApiServer="${K8S_API_SERVER_URL}" \
      exit 0;
  elif [[ "${UPGRADE_RELEASE_NAME}" == "oauth2-proxy" ]]
  then
    echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
    if [ ${DOMAIN_ACCESS} = true ];
    then
        helm secrets upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
        --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
        --set env.domain_access="true" --set env.is_domain_registered="${IS_DOMAIN_REGISTERED}" --set env.OBB_LB_IPADDR="${K8S_API_SERVER_HOST}" \
        --set env.OBB_HOST="${cluster_domain_name}" 3>&1 1>/dev/null 2>&3- 
    else 
        helm secrets upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
        --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
        --set env.domain_access="false" --set env.is_domain_registered="${IS_DOMAIN_REGISTERED}" --set env.OBB_HOST="${K8S_API_SERVER_HOST}" 3>&1 1>/dev/null 2>&3- 
    fi  
    exit 0;
####################################################
# XRT integration service deploy only when vernemq is deployed
####################################################
  elif [[ "${UPGRADE_RELEASE_NAME}" == "xrt" ]];
  then 
    if [[ $flags_xrt_enabled = true && $flags_vernemq_enabled = true ]];
    then
      #Upgrade IOTECH-XRT version
      VERNEMQ_USERNAME=$(sops --decrypt --extract "[\"cluster\"][\"secrets\"][\"vernemq\"][\"username\"]" ${CURDIR}/../secrets.yaml)
      VERNEMQ_PASSWORD=$(sops --decrypt --extract "[\"cluster\"][\"secrets\"][\"vernemq\"][\"password\"]" ${CURDIR}/../secrets.yaml)
      ansible-playbook -T 60 -i ${ANSIBLE_HOSTFILE} ${ANSIBLE_DIR}/xrt.yml -e "upgrade=true factoryDeploy=true xrtVersion=${cluster_iotech_version} hostName=localhost mqtt_username=${VERNEMQ_USERNAME} mqtt_password=${VERNEMQ_PASSWORD}" || { echo -e "\n${txtred}${txtbld}[ ERROR ]${txtrst} - Unable to run ansible XRT playbook.\n"; exit 1; }
      sudo apt-get -qq update && sudo apt-get -qq -y --only-upgrade install iotech-xrt-jci=${cluster_iotech_version} && sudo systemctl restart xrt
      echo "[ INFO ] Deploying ${RELEASE_NAME} integration service...!"
      helm secrets upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
      --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
      --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3- 
      #sleep 5
      #VERNEMQ_USERNAME=$(sops --decrypt --extract "[\"cluster\"][\"secrets\"][\"vernemq\"][\"username\"]" ${CURDIR}/../secrets.yaml)
      #VERNEMQ_PASSWORD=$(sops --decrypt --extract "[\"cluster\"][\"secrets\"][\"vernemq\"][\"password\"]" ${CURDIR}/../secrets.yaml)
      #ansible-playbook -T 60 -i ${ANSIBLE_HOSTFILE} ${ANSIBLE_DIR}/xrt.yml -e "hostName=${K8S_API_SERVER_HOST} mqtt_username=${VERNEMQ_USERNAME} mqtt_password=${VERNEMQ_PASSWORD}" || { echo -e "\n${txtred}${txtbld}[ ERROR ]${txtrst} - Unable to run ansible XRT playbook.\n"; exit 1; }
    fi
    exit 0;
####################################################
# NODE-RED deployment
####################################################
  elif [[ "${UPGRADE_RELEASE_NAME}" == "node-red" ]];
  then 
    if [ ${REPLICAS} == 1 ];
    then 
      echo "[ INFO ] Deploying ${RELEASE_NAME} integration service...!"
      helm secrets upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
      --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
      --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3-  
    else 
      echo "[ INFO ] Deploying ${RELEASE_NAME} integration service...!"
      helm secrets upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
      --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
      --set mongodb.ha=true --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3-
    fi 
    exit 0;
####################################################
  elif [[ "${UPGRADE_RELEASE_NAME}" == "${SERVICENAME}" ]];
  then
    echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
    helm secrets upgrade --install --wait --timeout 300s ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
    --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
    --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3- 
    exit 0;
  fi
  #Upgrade third party services
  if [ $optional_deploy = true ];
  then
    for OPTIONAL_REL_NAME in ${optional_services__ChartVersion[*]}
    do
      IFS=: read RELEASE_NAME CHART VERSION <<<"${OPTIONAL_REL_NAME}"
      if [[ "${RELEASE_NAME}" == "${SERVICENAME}" ]];
      then
        UPGRADE_RELEASE_NAME=${SERVICENAME};
        break;
      fi
    done
    if [[ "${UPGRADE_RELEASE_NAME}" == "${SERVICENAME}" ]];
    then
      echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
      helm upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
      --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
      --set ingress.oAuth=${INGRESS_AUTH} --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3- 
      exit 0;
    else
     echo "[ ERROR ] Unable to find the ${SERVICENAME} ...!"
    fi
  fi
fi

  ###############################################
if [[ "${SERVICENAME}" == "all" ]];
then
  ###############################################
  for CORE_REL_NAME in ${core_services__ChartVersion[*]}
  do
    IFS=: read RELEASE_NAME CHART VERSION <<<"${CORE_REL_NAME}"
    if [ "${RELEASE_NAME}" == "authorization-v2" ];
    then
      echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
      if [ ${DOMAIN_ACCESS} = true ];
      then
          helm secrets upgrade --install --wait --timeout 300s ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
          --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
          --set service.type=${SERVICETYPE} --set env.OB_OBBUri="https://${cluster_domain_name}" 3>&1 1>/dev/null 2>&3- 
      else
          helm secrets upgrade --install --wait --timeout 300s ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
          --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
          --set service.type=${SERVICETYPE} --set env.OB_OBBUri="https://${K8S_API_SERVER_HOST}" 3>&1 1>/dev/null 2>&3- 
      fi
  
    elif [ "${RELEASE_NAME}" == "assetmanagement" ];
    then 
      echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
      helm secrets upgrade --install --wait --timeout 300s ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
      --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
      --set ingress.oAuth=${INGRESS_AUTH} --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3- 
    
    elif [ "${RELEASE_NAME}" == "configuration-ui" ];
      then 
        echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
        kubectl -n $cluster_namespace create configmap connector-version \
        --from-literal factoryDeploy=false \
        --from-literal version=$(cat ${CURDIR}/../config.yml | grep -i connector | tr -d ' ' | awk -F ":" {'print $(NF-1)":"$(NF)'}) -o yaml --dry-run=client | kubectl apply -f -
        helm delete ${RELEASE_NAME} >> /dev/null 2>&1 
        helm secrets upgrade --install --wait --timeout 300s ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace "$cluster_namespace" \
        --set service.type=${SERVICETYPE} --set extraArgs.clusterApiServer="${cluster_api_server}" \
        --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
        --set ingress.oAuth=${INGRESS_AUTH} 3>&1 1>/dev/null 2>&3- 
        # --set extraArgs.hostIp="${K8S_API_SERVER_HOST}" --set extraArgs.clusterApiServer="${K8S_API_SERVER_URL}" \

    elif [[ "${RELEASE_NAME}" =~ .*"connector".* ]];
    then
      if [[ "${VAULT_STATUS}" = true ]];
      then
        IOTHUB_CONNECTION_TYPE=$(sops --decrypt --extract "[\"cluster\"][\"config\"][\"${RELEASE_NAME}\"][\"type\"]" ${CURDIR}/../secrets.yaml)
        if [ ${IOTHUB_CONNECTION_TYPE} == "string" ];
        then
          CONNECTION_URL=$(sops --decrypt --extract "[\"cluster\"][\"secrets\"][\"${RELEASE_NAME}\"][\"connection-url\"]" ${CURDIR}/../secrets.yaml)
        else
          IOTHUB_CERT_PASWORD=$(sops --decrypt --extract "[\"cluster\"][\"secrets\"][\"${RELEASE_NAME}\"][\"iothub-cert-password\"]" ${CURDIR}/../secrets.yaml)
          IOTHUB_CERT_PATH=$(sops --decrypt --extract "[\"cluster\"][\"config\"][\"${RELEASE_NAME}\"][\"iothub-cert-path\"]" ${CURDIR}/../secrets.yaml)
          IOTHUB_HOST_NAME=$(sops --decrypt --extract "[\"cluster\"][\"config\"][\"${RELEASE_NAME}\"][\"iothub-host-name\"]" ${CURDIR}/../secrets.yaml)
          IOTHUB_DEVICE_NAME=$(sops --decrypt --extract "[\"cluster\"][\"config\"][\"${RELEASE_NAME}\"][\"iothub-device-name\"]" ${CURDIR}/../secrets.yaml)
          [ -f "${IOTHUB_CERT_PATH}" ] && IOTHUB_CERT_CONTENT="$(cat ${IOTHUB_CERT_PATH} | openssl base64)" || ( echo " [ ERROR ] IOTHUB cert not found."; exit 1)
        fi
        #### Add the script to inject value to Vualt ####
        export VAULT_KEYSTORE_PATH="${HOME}/.obb"
        export VAULT_TOKEN="$(cat ${VAULT_KEYSTORE_PATH}/vault/vaultkeys | jq -r '.root_token')"
        kubectl exec -it vault-0 -- sh -c "export VAULT_TOKEN=${VAULT_TOKEN} && vault secrets enable -path=${RELEASE_NAME} kv-v2" 3>&1 1>/dev/null 2>&3- 
        if [ ${IOTHUB_CONNECTION_TYPE} == "string" ];
        then 
          kubectl exec -it vault-0 -- sh -c "export VAULT_TOKEN=${VAULT_TOKEN} && \
          vault kv put ${RELEASE_NAME}/iothub connectionString=\"${CONNECTION_URL}\"" 3>&1 1>/dev/null 2>&3- 
        else 
          kubectl exec -it vault-0 -- sh -c "export VAULT_TOKEN=${VAULT_TOKEN} && \
          vault kv put ${RELEASE_NAME}/iothub iothubHostName=\"${IOTHUB_HOST_NAME}\" \
          iothubDeviceName=\"${IOTHUB_DEVICE_NAME}\" iothubCertPassword=\"${IOTHUB_CERT_PASWORD}\" \
          iothubCertificate=\"${IOTHUB_CERT_CONTENT}\"" 3>&1 1>/dev/null 2>&3- 
        fi
        if [  $? -ne 0 ];
        then 
          echo "[ ERROR ] Unable to load the data into VAULT ...!"
          exit 1;
        fi
        kubectl exec -it vault-0 -- sh -c "export VAULT_TOKEN=${VAULT_TOKEN} && vault policy write ${RELEASE_NAME} - <<EOF
            path \"${RELEASE_NAME}/data/iothub\" {
            capabilities = [\"read\"]
          }
EOF"
        kubectl exec -it vault-0 -- sh -c "export VAULT_TOKEN=${VAULT_TOKEN} && vault write auth/kubernetes/role/${RELEASE_NAME} \
            bound_service_account_names=${RELEASE_NAME} \
            bound_service_account_namespaces=${cluster_namespace} \
            policies=${RELEASE_NAME} \
            ttl=24h"
      fi
      echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
      helm secrets upgrade --install --wait --timeout 300s ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
      --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
      --set service.type=${SERVICETYPE} --set vault.enabled=${VAULT_STATUS} -f ${CURDIR}/../secrets.yaml 3>&1 1>/dev/null 2>&3- 
    
    elif [[ "${RELEASE_NAME}" == "helm-api" ]];
    then
        echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
        helm secrets upgrade --install --wait --timeout 300s ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
        --set environments.harborRepoUrl="${jfrog_helm_repo_url}" --set environments.kubeconfig="${HOME}/.kube" \
        --set environments.harborUsername="$(echo ${jfrog_secret} |  base64 ${BASEDECODE} | jq -r '.auths |  to_entries | .[].value.username')" \
        --set environments.harborPassword="$(echo ${jfrog_secret} |  base64 ${BASEDECODE} | jq -r '.auths |  to_entries | .[].value.password')" \
        --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
        --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3- 
        #--set environments.hostIp="${K8S_API_SERVER_HOST}" --set extraArgs.clusterApiServer="${K8S_API_SERVER_URL}" \
    
    elif [[ "${RELEASE_NAME}" == "oauth2-proxy" ]]
    then
      echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
      if [ ${DOMAIN_ACCESS} = true ];
      then
          helm secrets upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
          --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
          --set env.domain_access="true" --set env.is_domain_registered="${IS_DOMAIN_REGISTERED}" --set env.OBB_LB_IPADDR="${K8S_API_SERVER_HOST}" \
          --set env.OBB_HOST="${cluster_domain_name}" 3>&1 1>/dev/null 2>&3- 
      elif [ ${FACTORY_DEPLOY} = true ];
      then
          helm secrets upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
          --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
          --set env.domain_access="true" --set env.is_domain_registered="${IS_DOMAIN_REGISTERED}" --set env.OBB_LB_IPADDR="${NODE_IPADDRESS}" \
          --set env.OBB_HOST="${cluster_domain_name}" 3>&1 1>/dev/null 2>&3- 
      else 
          helm secrets upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
          --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
          --set env.domain_access="false" --set env.is_domain_registered="${IS_DOMAIN_REGISTERED}" --set env.OBB_HOST="${K8S_API_SERVER_HOST}" 3>&1 1>/dev/null 2>&3- 
      fi  
  ####################################################
  # XRT integration service deploy only when vernemq is deployed
  ####################################################
    elif [[ "${RELEASE_NAME}" == "xrt" ]];
    then 
      if [[ $flags_xrt_enabled = true && $flags_vernemq_enabled = true ]];
      then
        ################################################
        #[OBB-298] XRT Upgrade Fix
        kubectl -n ${cluster_namespace} exec -it db-mongo-mongodb-0 -- mongo Xrt --quiet --eval 'db.MultiState.update({}, {$unset: {"Threshold": 1}}, {multi: true})' > /dev/null 2>&1 
        kubectl -n ${cluster_namespace} exec -it db-mongo-mongodb-0 -- mongo Xrt --quiet --eval 'db.MultiInput.update({}, { $unset: {"Threshold":1}}, {multi: true})' > /dev/null 2>&1 
        kubectl -n ${cluster_namespace} exec -it db-mongo-mongodb-0 -- mongo Xrt --quiet --eval 'db.MultiOutput.update({},{ $unset: {"Threshold":1}}, {multi: true})' > /dev/null 2>&1 
        ################################################
        #####
        # Add new property for iotech bacnet json
        sudo cp /opt/iotech/xrt/obb/config/bacnet.json /opt/iotech/xrt/obb/config/bacnet.json_$(date +%s)
        bacnet_data="$(jq --argjson newProp '{"DiscoverProperties": [75, 36, 28, 81, 85, 103, 117, 87, 104, 74, 32527, 45, 59, 77, 110, 4, 46, 2390, 121, 44, 112, 139, 107],"DiscoverObjects": [8, 0, 1, 2, 3, 4, 5, 13, 14, 19]}' '.Driver |= .+ $newProp' /opt/iotech/xrt/obb/config/bacnet.json)" \
        && echo "${bacnet_data}" | sudo tee /opt/iotech/xrt/obb/config/bacnet.json > /dev/null 2>&1 
        #####
        echo "[ INFO ] Deploying ${RELEASE_NAME} integration service...!"
        helm secrets upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
        --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
        --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3- 
        #sleep 5
        #VERNEMQ_USERNAME=$(sops --decrypt --extract "[\"cluster\"][\"secrets\"][\"vernemq\"][\"username\"]" ${CURDIR}/../secrets.yaml)
        #VERNEMQ_PASSWORD=$(sops --decrypt --extract "[\"cluster\"][\"secrets\"][\"vernemq\"][\"password\"]" ${CURDIR}/../secrets.yaml)
        #ansible-playbook -T 60 -i ${ANSIBLE_HOSTFILE} ${ANSIBLE_DIR}/xrt.yml -e "hostName=${K8S_API_SERVER_HOST} mqtt_username=${VERNEMQ_USERNAME} mqtt_password=${VERNEMQ_PASSWORD}" || { echo -e "\n${txtred}${txtbld}[ ERROR ]${txtrst} - Unable to run ansible XRT playbook.\n"; exit 1; }
      fi
  ####################################################
  # NODE-RED deployment
  ####################################################
    elif [[ "${CHART}" == "node-red" ]];
    then 
      if [ ${REPLICAS} == 1 ];
      then 
        echo "[ INFO ] Deploying ${RELEASE_NAME} integration service...!"
        helm secrets upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
        --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
        --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3-  
      else 
        echo "[ INFO ] Deploying ${RELEASE_NAME} integration service...!"
        helm secrets upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
        --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
        --set mongodb.ha=true --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3-
      fi 
  ####################################################  
    else
      echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
      helm secrets upgrade --install --wait --timeout 300s ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
      --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
      --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3- 
    fi
  done

  if [ $optional_deploy = true ];
  then
    for OPTIONAL_REL_NAME in ${optional_services__ChartVersion[*]}
    do
      IFS=: read RELEASE_NAME CHART VERSION <<<"${OPTIONAL_REL_NAME}"
      echo "[ INFO ] Upgrading ${RELEASE_NAME} to v${VERSION} ...!"
      helm upgrade --install --wait ${RELEASE_NAME} openbluebridge/${CHART} --version ${VERSION} --namespace ${cluster_namespace} \
      --set ingHostnameOverride="${cluster_domain_name}" --set ingSecretOverride="mayflower-ingress-cert" \
      --set ingress.oAuth=${INGRESS_AUTH} --set service.type=${SERVICETYPE} 3>&1 1>/dev/null 2>&3- 
    done
  fi
fi
#############################################################
# Connector upgrade
#############################################################
CONNECTOR_LIST="$(kubectl get deployments -l app=connector --no-headers=true | awk {'print $1'})"
CONNECTOR_VERSION="$(cat ${CURDIR}/../config.yml | grep -i connector | tr -d ' ' | awk -F ":" {'print $(NF)'})"
for CONNECTOR_RELEASE_NAME in ${CONNECTOR_LIST}
do
  #Enable kube config secrets for vault
  export VAULT_KEYSTORE_PATH="${HOME}/.obb"
  export VAULT_TOKEN="$(cat ${VAULT_KEYSTORE_PATH}/vault/vaultkeys | jq -r '.root_token')"
  kubectl -n ${cluster_namespace} exec -it vault-0 -- sh -c "export VAULT_TOKEN=${VAULT_TOKEN} && vault write auth/kubernetes/config \
      issuer=\"https://kubernetes.default.svc.cluster.local\" \
      disable_iss_validation=\"true\" \
      token_reviewer_jwt=\"\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)\" \
      kubernetes_host=\"https://\$KUBERNETES_PORT_443_TCP_ADDR:443\" \
      kubernetes_ca_cert=\"\$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)\"" > /dev/null 2>&1

  #CURR_CONNECTOR_VER="$(helm ls --skip-headers -o json -f ${CONNECTOR_RELEASE_NAME} | jq -r .[].chart | awk -F '-' {'print $(NF)'})"
  CURR_CONNECTOR_VER="$(helm ls --skip-headers | grep -w ${CONNECTOR_RELEASE_NAME} | awk {'print $(NF-1)'} | awk -F '-' {'print $(NF)'})"
  if [ ! -z "$CURR_CONNECTOR_VER" ];
  then 
    IOTHUB_CONNECTION_TYPE=$(sops --decrypt --extract "[\"cluster\"][\"config\"][\"connector\"][\"type\"]" ${CURDIR}/../secrets.yaml)        
    echo "[ INFO ] Upgrading ${CONNECTOR_RELEASE_NAME} to v${CONNECTOR_VERSION} ...!"
    helm upgrade --install --wait ${CONNECTOR_RELEASE_NAME} openbluebridge/connector \
      --version ${CONNECTOR_VERSION} \
      --namespace ${cluster_namespace} \
      --set vault.enabled=true \
      --set cluster.config.${CONNECTOR_RELEASE_NAME}.type="${IOTHUB_CONNECTION_TYPE}" \
      --set cluster.config.${CONNECTOR_RELEASE_NAME}.serviceaccountname="${CONNECTOR_RELEASE_NAME}" \
      --set cluster.config.${CONNECTOR_RELEASE_NAME}.hashicorp.role="${CONNECTOR_RELEASE_NAME}" \
      --set cluster.config.${CONNECTOR_RELEASE_NAME}.iothubsecretpath="${CONNECTOR_RELEASE_NAME}/data/iothub" \
      --set cluster.secrets.${CONNECTOR_RELEASE_NAME}="null"
  fi
done
################################################
# Cleanup unused services
echo "[ INFO ] Cleaning up unused services."
helm delete hazelcast -n ${cluster_namespace} > /dev/null 2>&1
[ $DEV_MODE = false ] && helm delete kubernetes-dashboard -n infra > /dev/null 2>&1
################################################
