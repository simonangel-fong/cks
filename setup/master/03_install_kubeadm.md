# CKS setup: master install kubeadm

```sh
K8S_VERSION="v1.33"

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
# Install kubelet kubeadm kubectl
# ##############################
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

# Enable the kubelet service
sudo systemctl enable --now kubelet
sudo systemctl status kubelet --no-page

# confirm client version
kubectl version --client

# ##############################
# Configure crictl
# ##############################
echo
echo "/n########## Configure crictl ##########/n"

# confirm
sudo crictl ps
```
