# k8spilot
k8spilot可以简单、快速的搭建一个生产级别，纯净的Kuebrnetes集群；能帮你完成搭建Kubernetes集群时所有复杂的操作，你要做的，只需要提供运行Kubernetes的主机或服务器。k8spilot安装Kubernetes集群的速度取决于你电脑和服务器的互联网下载速度。

## 功能概述
+ 离线安装Kubernetes集群和网络等插件，不需要互联网在线下载集群组件和镜像
+ Kubernetes安装版本可选择，可选的版本列表参见: [版本列表](https://dl.k8spilot.icu/kubernetes/kube-versions)
+ Kubernetes所有组件裸运行在系统中，而不是容器化部署，更稳定和易维护
+ 一键化横向扩容Kubernetes集群节点（开发中）
+ 无docker，采用更现代的containerd作为容器运行时
+ 自签集群证书，有效期100年，解决集群证书过期困扰
+ 高性能网络插件cilium，默认开启BPF模式（网络插件可选calico）
+ 支持ARM架构服务器，自适应部署对应架构Kubernetes
+ 默认安装CoreDNS为集群内部DNS
+ 默认安装helm工具，helm安装在master节点上
+ 可选安装csi-driver-nfs作为集群默认StorageClass
+ 可选安装ingress-nginx作为集群默认IngressClass


## Requirements

:bulb: **主控端**  

主控端是运行k8spilot的机器，可以是你的笔记本电脑，可以是一台独立服务器，也可以是被控端机器中的任意一台。主控端需要满足以下要求  

+ 主控端要求能连接互联网，能使用root通过ssh登录所有被控端(如果主控端不能连接互联网，请参见离线方案: k8spilot-offline)
+ 主控端必须是Linux/MacOS，不支持Windows（Windows使用docker或者wsl方案替代）
+ 主控端必须安装了Python 3.10及以上版本，否则，需要升级Python版本，参见：[Python安装方法](docs/getting_started/install-python.md)    

:bulb: **被控端**  

被控端用于安装Kubernetes集群的虚拟机或者服务器，被控端需要满足以下要求  

+ 被控端只能是Linux，且内核版本>=5.4,受支持的Linux发现版本见：[支持的Linux发行版本](#支持的Linux发行版本)
+ 被控端至少要3台虚拟机或服务器，其中一台作为控制平面（master），也可同时作为调度节点（node）
+ 所有被控端CPU架构（x86_64/aarch64）必须一致；为了避免异常问题，建议操作系统以及系统版本也保持一致
+ 被控端要求能连接互联网，并且所有被控端之间网络互通(如果被控端不能连接互联网，请参见离线方案: k8spilot-offline)
+ 所有被控端Python版本必须>=3.8

> **Tips**: 请根据你的服务要求，合理的选择被控端服务器/虚拟机的硬件配置，避免过小配置影响容器在节点上的正常运行

## 快速开始

如果主控端安装有Docker服务，推荐使用k8spilot的Docker镜像，可避免主控端复杂的环境和依赖问题。

[Docker方式使用k8spilot](docs/getting_started/getting-started.md#docker方式使用k8spilot)

没有Docker也不必担心，只需简单几步就能安装k8spilot，见

[Getting started](docs/getting_started/getting-started.md)


## 支持的Linux发行版本
以下Linux发行版支持作为被控端安装Kubernetes集群  

|Linux Distribution | Version | Status |
| - | - | - |
| :penguin: **CentOS Stream** | 9/10 | :white_check_mark: |
| :penguin: **Rocky Linux** | 8/9/10 | :white_check_mark: |
| :penguin: **Oracle Linux** | 8/9/10 | :white_check_mark: |
| :penguin: **Debian** | Bullseye/Bookworm | :white_check_mark: |
| :penguin: **Ubuntu** | 22.04/24.04 | :white_check_mark: |
| :penguin: **Fedore** | 39/40 | :white_check_mark: |
| :penguin: **openSUSE** | | :white_check_mark: | 
| :penguin: **openEuler** | 2203/2403 | :white_check_mark: |
| :penguin: **Alibaba Cloud Linux** | 3 | :white_check_mark: |
| :penguin: **Kylin Linux Advanced Server V10** | 2403/2503 | :white_check_mark: |

## 集群组件版本矩阵
|component name | version |
| - | - |
| **kubernetes** | v1.30.4+ |
| **etcd** | v3.6.2 |
| **containerd** | v1.7.28/v2.1.3 |
| **runc** | v1.3.0 |
| **cni-plugins** | v1.7.1 |
| **pause** | v3.9 |
| **CoreDNS** | v1.12.2 |

## 工具
+ **helm** v3.17.4

## 存储插件
+ **csi-driver-nfs** v4.11.0

## 网络插件
+ **clilum** v1.16.12
+ **calico** v3.30.2

> 网络插件安装时默认开启BPF模式，kube-proxy将被忽略安装

## Ingress Plugins
+ **cilium ingress** 安装cilium网络时，默认开启cilium ingress功能作为默认ingress
+ **ingress-nginx** 可选安装ingress-nginx作为默认ingress

## 高级选项
k8spilot支持自定义安装配置，选择/关闭部分插件和调整插件版本，请查看配置文件说明，文档待补充