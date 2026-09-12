# CKS setup: master install kubeadm

```sh
K8S_VERSION="v1.35"

# ##############################
# Install support packages
# ##############################
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# ##############################
# Configure Kubernetes apt repo
# ##############################
sudo mkdir -pv /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# ##############################
# Install kubelet kubeadm kubectl cri-tools
# ##############################
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl cri-tools
sudo apt-mark hold kubelet kubeadm kubectl cri-tools

# Enable the kubelet service
sudo systemctl enable --now kubelet

# Verify the client version
kubectl version --client
# Client Version: v1.35.8
# Kustomize Version: v5.7.1

# ##############################
# Configure crictl
# ##############################
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

# Verify runtime connectivity
sudo crictl ps
```
