#/usr/bin/bash

distro_id=$(cat /etc/os-release | grep '^ID=' | cut -d '=' -f 2)

if [ $distro_id = ubuntu ]; then
    apt install -y conntrack socat curl wget
else
    echo "Not an Ubuntu system, can not install"
    return 1
fi

DOWNLOAD_DIR="/usr/local/bin"
ARCH="amd64"
RUNC_VERSION="v1.1.13"
CONTAINERD_VERSION="1.7.20"
CRICTL_VERSION="v1.30.0"
CNI_PLUGINS_VERSION="v1.3.0"
KUBERNETES_TEMPLATES_RELEASE="v0.16.2"
KUBERNETES_RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"


if ldd /bin/ls | grep musl; then
    echo "This script is only tested to work on glibc systems, if you know what you're doing and wish to continue press Enter"
    read
fi

wget(){
  /usr/bin/wget -nv $@
}

echo "Enabling net.ipv4.ip_forward"
which sysctl && \
! grep "^net.ipv4.ip_forward" /etc/sysctl.conf &&
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl net.ipv4.ip_forward=1

echo "Disabling swap"
swapoff -a

echo "Downloading binaries"

# Containerd
wget -O "${DOWNLOAD_DIR}/runc" "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.${ARCH}"
chmod +x ${DOWNLOAD_DIR}/runc

wget "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
tar Cxzvf /usr/local "containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
rm containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz
wget -O /usr/lib/systemd/system/containerd.service "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service"

# CRICTL
wget "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz"
sudo tar zxvf crictl-${CRICTL_VERSION}-linux-amd64.tar.gz -C ${DOWNLOAD_DIR}
rm -f crictl-${CRICTL_VERSION}-linux-amd64.tar.gz

# CNI Plugins
DEST="/opt/cni/bin"
sudo mkdir -p "$DEST"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz" | sudo tar -C "$DEST" -xz


# KUBEs
mkdir -p "$DOWNLOAD_DIR"
wget -O "/usr/local/bin/kubeadm" https://dl.k8s.io/release/${KUBERNETES_RELEASE}/bin/linux/${ARCH}/kubeadm
wget -O "/usr/local/bin/kubectl" https://dl.k8s.io/release/${KUBERNETES_RELEASE}/bin/linux/${ARCH}/kubectl
wget -O "/usr/local/bin/kubelet" https://dl.k8s.io/release/${KUBERNETES_RELEASE}/bin/linux/${ARCH}/kubelet
chmod +x "$DOWNLOAD_DIR/kubectl" && chmod +x "$DOWNLOAD_DIR/kubelet" && chmod +x "$DOWNLOAD_DIR/kubeadm"

curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${KUBERNETES_TEMPLATES_RELEASE}/cmd/krel/templates/latest/kubelet/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /usr/lib/systemd/system/kubelet.service
mkdir -p /usr/lib/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${KUBERNETES_TEMPLATES_RELEASE}/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf


mkdir -p /etc/containerd
cp $(pwd)/systemd-containerd-config-that-always-works.toml /etc/containerd/config.toml
systemctl daemon-reload

systemctl enable --now containerd.service
systemctl enable kubelet.service
