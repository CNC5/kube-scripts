#/usr/bin/bash

distro_id=$(cat /etc/os-release | grep '^ID=' | cut -d '=' -f 2)
if [ $distro_id = ubuntu ]; then
    apt install conntrack socat
else
    echo "Not an Ubuntu system, can not install"
    return 1
fi

if ldd /bin/ls | grep musl; then
    echo "This script is only tested to work on glibc systems, if you know what you're doing and wish to continue press Enter"
    read
else
    ;
fi

echo "Enabling net.ipv4.ip_forward"
which sysctl && \
! grep "^net.ipv4.ip_forward" /etc/sysctl.conf &&
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl net.ipv4.ip_forward=1

echo "Disabling swap"
swapoff -a

echo "Downloading binaries"
ARCH="amd64"

# Containerd
RUNC_VERSION="v1.1.13"
wget -O "/usr/local/bin/runc" "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.${ARCH}"
chmod +x /usr/local/bin/runc

CONTAINERD_VERSION="1.7.20"
wget "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
tar Cxzvf /usr/local "containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
rm containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz
wget -O /usr/lib/systemd/system/containerd.service "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service"

# CRICTL
VERSION="v1.30.0"
wget "https://github.com/kubernetes-sigs/cri-tools/releases/download/${VERSION}/crictl-${VERSION}-linux-amd64.tar.gz"
sudo tar zxvf crictl-${VERSION}-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-${VERSION}-linux-amd64.tar.gz

# CNI Plugins
CNI_PLUGINS_VERSION="v1.3.0"
DEST="/opt/cni/bin"
sudo mkdir -p "$DEST"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz" | sudo tar -C "$DEST" -xz


# KUBEs
DOWNLOAD_DIR="/usr/local/bin"
mkdir -p "$DOWNLOAD_DIR"
RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
cd $DOWNLOAD_DIR
curl -L --remote-name-all https://dl.k8s.io/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}
chmod +x "$DOWNLOAD_DIR/kube*"

RELEASE_VERSION="v0.16.2"
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/krel/templates/latest/kubelet/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /usr/lib/systemd/system/kubelet.service
mkdir -p /usr/lib/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf


mkdir -p /etc/containerd
cp systemd-containerd-config-that-always-works.toml /etc/containerd/config.toml
systemctl daemon-reload

systemctl enable --now containerd
systemctl enable kubelet.service
