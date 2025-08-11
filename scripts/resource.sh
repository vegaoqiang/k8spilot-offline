#!/bin/bash
# Author: vegaoqiang

VAR="all.yml"
ENV="production"
if [ ! -z "${K8SPILOT}" ]; then
  ENV="local"
fi

VAR_FILE="$(dirname ${BASH_SOURCE[0]})/../inventories/${ENV}/group_vars/${VAR}"
RESOURCE_DIR="$(dirname ${BASH_SOURCE[0]})/../artifacts"

if [ -d "${RESOURCE_DIR}" ]; then
  mkdir -p ${RESOURCE_DIR}/images
fi

dl_handler(){
  local dl_url=$1
  local file_name=$2
  curl --retry 3 --retry-delay 5 -L ${dl_url} -o ${RESOURCE_DIR}/${file_name}
  if [ "$?" -ne 0 ]; then 
    return 1
  fi
  printf "${RESOURCE_DIR}/${file_name}"
}

validation_sha256sum(){
  local local_sha=$1
  local remote_sha=$2
  if [ -z "${local_sha}" ] || [ -z "${remote_sha}" ]; then
    echo "本地或远程sha256sum值不能为空"
    exit 1
  fi
  if [ "${local_sha}" != "${remote_sha}" ]; then
    echo "本地sha256sum值 ${local_sha} 与远程值 ${remote_sha} 不匹配"
    echo "请检查下载的文件是否完整或被篡改"
    exit 1
  fi
  echo "sha256sum校验通过"
}

lookup_sha256_online(){
  local sha_url=$1
  local sha256sum=$(curl --retry 3 --retry-delay 5 --max-time 10 -L ${sha_url})
  if [ "$?" -ne 0 ] || [ -z "${sha256sum}" ]; then
    return 1
  fi
  printf "${sha256sum}"
}

dl_and_validation(){
  local file_url=$1
  local sha256sum_url=$2
  local file_name=$3
  local dl_file_path=$(dl_handler "${file_url}" "${file_name}")
  if [ "$?" -ne 0 ]; then
    echo "下载 ${file_name} 失败"
    exit 1
  fi
  echo "已下载 ${file_name} 到 ${dl_file_path}"

  local local_sha256sum=$(sha256sum ${dl_file_path} | awk '{print $1}')
  # 提供了sha256sum_url必须要校验本地和远程的sha256sum
  if [ ! -z "${sha256sum_url}" ]; then
    local remote_sha256sum=$(lookup_sha256_online "${sha256sum_url}") 
    if [ "$?" -ne 0 ]; then
      echo "获取远程${sha256sum_url}失败"
      exit 1
    fi
    if [ $(echo ${remote_sha256sum}|wc -l|xargs) -gt 1 ]; then
      echo "远程${sha256sum_url}返回了多个sha256sum值"
      remote_sha256sum=$(echo ${remote_sha256sum}|grep ${file_name}) # 部分软件将多个文件的sha256sum放在同一个文件中
    fi
    validation_sha256sum "${local_sha256sum// *}" "${remote_sha256sum// *}"
  fi
  
  echo "${local_sha256sum}" >> ${RESOURCE_DIR}/sha256sums.txt
}

dl_containerd(){
  local arch_type=$1
  local version=$2
  local file_name="containerd-${version##*v}-linux-${arch_type}.tar.gz"
  local file_url="https://github.com/containerd/containerd/releases/download/${version}/containerd-${version##*v}-linux-${arch_type}.tar.gz"
  local sha256sum_url="https://github.com/containerd/containerd/releases/download/${version}/containerd-${version##*v}-linux-${arch_type}.tar.gz.sha256sum"
  dl_and_validation "${file_url}" "${sha256sum_url}" "${file_name}"
}

dl_etcd(){
  local arch_type=$1
  local version=$2
  local file_name="etcd-${version}-linux-${arch_type}.tar.gz"
  local file_url="https://github.com/etcd-io/etcd/releases/download/${version}/etcd-${version}-linux-${arch_type}.tar.gz"
  local sha256sum_url="https://github.com/etcd-io/etcd/releases/download/${version}/SHA256SUMS"
  dl_and_validation "${file_url}" "${sha256sum_url}" "${file_name}"
}

dl_runc(){
  local arch_type=$1
  local version=$2
  local file_name="runc.${arch_type}"
  local file_url="https://github.com/opencontainers/runc/releases/download/${version}/runc.${arch_type}"
  local sha256sum_url="https://github.com/opencontainers/runc/releases/download/${version}/runc.sha256sum"
  dl_and_validation "${file_url}" "${sha256sum_url}" "${file_name}"
}

dl_cni_plugins(){
  local arch_type=$1
  local version=$2
  local file_name="cni-plugins-linux-${arch_type}-${version}.tgz"
  local file_url="https://github.com/containernetworking/plugins/releases/download/${version}/cni-plugins-linux-${arch_type}-${version}.tgz"
  local sha256sum_url="https://github.com/containernetworking/plugins/releases/download/${version}/cni-plugins-linux-${arch_type}-${version}.tgz.sha256"
  dl_and_validation "${file_url}" "${sha256sum_url}" "${file_name}"
}

dl_helm(){
  local arch_type=$1
  local version=$2
  local file_name="helm-${version}-linux-${arch_type}.tar.gz"
  local file_url="https://get.helm.sh/${file_name}"
  local sha256sum_url="https://get.helm.sh/${file_name}.sha256sum"
  dl_and_validation "${file_url}" "${sha256sum_url}" "${file_name}"
}

dl_kube_binaries(){
  local arch_type=$1
  local version=$2
  local componemens=(kubectl kube-apiserver kube-controller-manager kube-scheduler kubectl kubelet)
  for file in "${componemens[@]}"; do
    local file_name="${file}"
    local file_url="https://dl.k8s.io/${version}/bin/linux/${arch_type}/${file_name}"
    local sha256sum_url="https://dl.k8s.io/${version}/bin/linux/amd64/${file_name}.sha256"
    dl_and_validation "${file_url}" "${sha256sum_url}" "${file_name}"
  done
}

dl_tigera_operator(){
  local arch_type=$1
  local version=$2
  local file_name="tigera-operator-${version}.tgz"
  local file_url="https://github.com/projectcalico/calico/releases/download/${version}/tigera-operator-${version}.tgz"
  local sha256sum_url="https://github.com/projectcalico/calico/releases/download/${version}/SHA256SUMS"
  dl_and_validation "${file_url}" "${sha256sum_url}" "${file_name}"
}

dl_cilium(){
  local arch_type=$1
  local version=$2
  local file_name="cilium-${version}.tgz"
  local file_url="https://raw.githubusercontent.com/cilium/charts/refs/heads/master/${file_name}"
  local sha256sum_url=""
  dl_and_validation "${file_url}" "${sha256sum_url}" "${file_name}"
}

dl_csi(){
  local arch_type=$1
  local version=$2
  local file_name="csi-driver-nfs-${version##*v}.tgz"
  local file_url="https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/refs/heads/master/charts/${version}/${file_name}"
  local sha256sum_url=""
  dl_and_validation "${file_url}" "${sha256sum_url}" "${file_name}"
}

dl_ingress(){
  local arch_type=$1
  local version=$2
  local file_name="ingress-nginx-${version}.yaml"
  local file_url="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${version}/deploy/static/provider/cloud/deploy.yaml"
  local sha256sum_url=""
  dl_and_validation "${file_url}" "${sha256sum_url}" "${file_name}"
}

dl_cfssl(){
  local arch_type=$1
  local version=$2
  local componemens=("cfssl" "cfssljson")
  local sha256sum_url="https://github.com/cloudflare/cfssl/releases/download/${version}/cfssl_${version##*v}_checksums.txt"
  for file in "${componemens[@]}"; do
    local file_name="${file}_${version##*v}_linux_${arch_type}"
    local file_url="https://github.com/cloudflare/cfssl/releases/download/${version}/${file_name}"
    dl_and_validation "${file_url}" "${sha256sum_url}" "${file_name}"
  done
}