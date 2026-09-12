# CKS setup: master install containerd

```sh
# ##############################
# Install containerd
# ##############################
sudo apt-get update
sudo apt-get install -y containerd

# ##############################
# Configure containerd
# ##############################
# Generate default config
sudo mkdir -pv /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Set systemd cgroup driver: Sets SystemdCgroup = true
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# apply the change
sudo systemctl restart containerd
sudo systemctl enable --now containerd
sudo systemctl status containerd --no-page
```
