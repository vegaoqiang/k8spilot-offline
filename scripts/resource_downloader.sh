#!/bin/bash
# Author: vegaoqiang

VAR="all.yml"
ENV="production"
if [ ! -z "${K8SPILOT}" ]; then
  ENV="local"
fi

VAR_FILE="$(dirname ${BASH_SOURCE[0]})/../inventories/${ENV}/group_vars/${VAR}"
RESOURCE_DIR="$(dirname ${BASH_SOURCE[0]})/../artifacts"

if [ ! -d "${RESOURCE_DIR}" ]; then
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
  printf -- "%s" "${sha256sum}"
}

dl_and_validation(){
  local file_url=$1
  local sha256sum_url=$2
  local file_name=$3
  echo "开始从 ${file_url} 下载 ${file_name}"
  # local dl_file_path=$(dl_handler "${file_url}" "${file_name}")
  if ! dl_file_path=$(dl_handler "${file_url}" "${file_name}"); then
    echo "下载 ${file_name} 失败"
    exit 1
  fi
  echo "已下载 ${file_name} 到 ${dl_file_path}"

  local local_sha256sum=$(sha256sum ${dl_file_path})
  # 提供了sha256sum_url必须要校验本地和远程的sha256sum
  if [ ! -z "${sha256sum_url}" ]; then
    if ! remote_sha256sum=$(lookup_sha256_online "${sha256sum_url}") ; then
      echo "获取远程${sha256sum_url}失败"
      exit 1
    fi
    if [ $(echo "${remote_sha256sum}"|wc -l|xargs) -gt 1 ]; then
      echo "远程${sha256sum_url}返回了多个sha256sum值"
      remote_sha256sum=$(echo "${remote_sha256sum}"|grep ${file_name}) # 部分软件将多个文件的sha256sum放在同一个文件中
    fi
    validation_sha256sum "${local_sha256sum// *}" "${remote_sha256sum// *}"
  fi
  
  echo "${local_sha256sum// *}  ${file_name}" >> ${RESOURCE_DIR}/sha256sums
}

get_dl_version(){
  local version_name=$1
  local version=$(cat ${VAR_FILE} | grep "${version_name}"|awk '{print $NF}'|xargs)
  if [ -z "${version}" ]; then
    return 1 
  fi
  printf "${version}"
}

get_kube_version(){
  if [ -z "${KUBE_VERSION}" ]; then
    local kube_version="v1.33.3"
  else
    local kube_version="${KUBE_VERSION}"
  fi
  echo "${kube_version}" > ${RESOURCE_DIR}/kube-version
  printf "${kube_version}"
}

dl_containerd(){
  local arch_type=$1
  local version=$2
  local file_name="containerd-${version}-linux-${arch_type}.tar.gz"
  local file_url="https://github.com/containerd/containerd/releases/download/v${version}/containerd-${version}-linux-${arch_type}.tar.gz"
  local sha256sum_url="https://github.com/containerd/containerd/releases/download/v${version}/containerd-${version}-linux-${arch_type}.tar.gz.sha256sum"
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

dl_kube(){
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
  local sha256sum_url="https://github.com/cloudflare/cfssl/releases/download/v${version}/cfssl_${version}_checksums.txt"
  for file in "${componemens[@]}"; do
    local file_name="${file}_${version}_linux_${arch_type}"
    local file_url="https://github.com/cloudflare/cfssl/releases/download/v${version}/${file_name}"
    dl_and_validation "${file_url}" "${sha256sum_url}" "${file_name}"
  done
}

dl_components(){
  local arch_type=$1
  if [ ! -f ${VAR_FILE} ]; then
    echo "缺少 ${VAR_FILE} 文件"
    exit 1
  fi
  cfssl_version=$(get_dl_version "cfssl_version") || { echo "无法获取 cfssl_version 版本"; exit 1; }
  ingress_version=$(get_dl_version "ingress_nginx_version") || { echo "无法获取 ingress_nginx_version 版本"; exit 1; }
  csi_version=$(get_dl_version "csi_nfs_version") || { echo "无法获取 csi_nfs_version 版本"; exit 1; }
  cilium_version=$(get_dl_version "cilium_version") || { echo "无法获取 cilium_version 版本"; exit 1; }
  tigera_operator_version=$(get_dl_version "calico_version") || { echo "无法获取 calico_version 版本"; exit 1; }
  helm_version=$(get_dl_version "helm_version") || { echo "无法获取 helm_version 版本"; exit 1; }
  cni_plugins_version=$(get_dl_version "cni_version") || { echo "无法获取 cni_version 版本"; exit 1; }
  runc_version=$(get_dl_version "runc_version") || { echo "无法获取 runc_version 版本"; exit 1; }
  etcd_version=$(get_dl_version "etcd_version") || { echo "无法获取 etcd_version 版本"; exit 1; }
  containerd_version=$(get_dl_version "containerd_version") || { echo "无法获取 containerd_version 版本"; exit 1; }
  
  dl_cfssl $arch_type $cfssl_version
  dl_ingress $arch_type $ingress_version
  dl_csi $arch_type $csi_version
  dl_cilium $arch_type $cilium_version
  dl_tigera_operator $arch_type $tigera_operator_version
  dl_helm $arch_type $helm_version
  dl_cni_plugins $arch_type $cni_plugins_version
  dl_runc $arch_type $runc_version
  dl_etcd $arch_type $etcd_version
  dl_containerd $arch_type $containerd_version
}


image_handler(){
  local arch_type=$1
  local image_repo=$2
  local local_path=$3
  echo "pull image ${image_repo} to ${local_path}"
  crane pull --platform linux/${arch_type} ${image_repo} ${local_path}
  if [ "$?" -ne 0 ]; then
    echo "拉取镜像 ${image_repo} 失败"
    exit 1
  fi
  echo "已拉取镜像 ${image_repo} 到 ${local_path}"
}


pull_image(){
  local arch_type=$1
  local local_dir=$2
  local version_file_name=$3
  local local_path="${RESOURCE_DIR}/${local_dir}"
  if [ ! -d "${local_path}" ]; then
    mkdir -p ${local_path}
  fi
  local version_file_path="$(dirname ${BASH_SOURCE[0]})/../versions/${version_file_name}"
  if [ ! -f "${version_file_path}" ]; then
    echo "缺少 ${version_file_path} 文件"
    exit 1
  fi
  local images_list=$(cat ${version_file_path} | grep -vE '^\s*#' | grep -vE '^\s*$')
  for image_repo in ${images_list}; do
    local image_name=${image_repo##*/}
    image_name=${image_name%%:*}
    local image_version=${image_repo##*:}
    local local_file="${image_name}_${image_version}_${arch_type}.tar"
    image_handler "${arch_type}" "${image_repo}" "${local_path}/${local_file}"
  done
}

pull_ingress_nginx_image(){
  local arch_type=$1
  local version_file_name="ingress-nginx"
  local local_dir="images/ingress-nginx"
  pull_image "${arch_type}" "${local_dir}" "${version_file_name}"
}

pull_cilium_image(){
  local arch_type=$1
  local version_file_name="cilium"
  local local_dir="images/cilium"
  pull_image "${arch_type}" "${local_dir}" "${version_file_name}"
} 

pull_csi_image(){
  local arch_type=$1
  local version_file_name="csi"
  local local_dir="images/csi-driver-nfs"
  pull_image "${arch_type}" "${local_dir}" "${version_file_name}"
}

pull_coredns_image(){
  local arch_type=$1
  local version_file_name="coredns"
  local local_dir="images/coredns"
  pull_image "${arch_type}" "${local_dir}" "${version_file_name}"
} 

pull_calico_image(){
  local arch_type=$1
  local version_file_name="calico"
  local local_dir="images/calico"
  pull_image "${arch_type}" "${local_dir}" "${version_file_name}"
} 

pull_pause_image(){
  local arch_type=$1
  local version_file_name="pause"
  local local_dir="images/pause"
  pull_image "${arch_type}" "${local_dir}" "${version_file_name}"
}

pull_pilot_image(){
  local arch_type=$1
  local version_file_name="k8spilot"
  local local_dir="images/k8spilot"
  pull_image "${arch_type}" "${local_dir}" "${version_file_name}"
}

dl_images(){
  local arch_type=$1
  pull_ingress_nginx_image "${arch_type}"
  pull_cilium_image "${arch_type}"
  pull_csi_image "${arch_type}"
  pull_coredns_image "${arch_type}"
  pull_calico_image "${arch_type}"
  pull_pause_image "${arch_type}"
  pull_pilot_image "${arch_type}"
}

main(){
  if [ -z "${arch_type}" ]; then
    echo "arch_type 不能为空, 请使用 -p 选项指定架构类型 (amd64 或 arm64)"
    exit 1
  fi
  if [ "${arch_type}" != "amd64" ] && [ "${arch_type}" != "arm64" ]; then
    echo "arch_type 只能是 amd64 或 arm64"
    exit 1
  fi
  if [ -z "${specify_download}" ]; then
    dl_components "${arch_type}"
    dl_images "${arch_type}"
    dl_kube "${arch_type}" "$(get_kube_version)"
  elif [ "${specify_download}" == "kube" ]; then
    dl_kube "${arch_type}" "$(get_kube_version)"
  elif [ "${specify_download}" == "image" ]; then
    dl_images "${arch_type}"
  elif [ "${specify_download}" == "component" ]; then
    dl_components "${arch_type}"
  else
    echo "未知的下载选项: ${specify_download}, 可选值为 kube, image, component 或不指定"
    exit 1
  fi
  echo "${specify_download}资源下载完成"
}


# -p: platform, amd64 or arm64
# -s: specify download file, kube, image or comonent, if not set, download all
# -k: kube_version, specify the Kubernetes version to download, v1.33.3 by default
# Usage: ./resource_downloader.sh -p amd64 -s kube -k v1.33.3
while getopts ":p:s:k" opt; do
  case $opt in
    p)
      arch_type=$OPTARG
      ;;
    s)
      specify_download=$OPTARG
      ;;
    k)
      KUBE_VERSION=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done 

main