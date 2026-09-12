# CKS setup: master install containerd

```sh
# Enable IPv4 forwarding.
sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

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

# Use the systemd cgroup driver.
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Apply the configuration.
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl status containerd --no-page
# ● containerd.service - containerd container runtime
#      Loaded: loaded (/usr/lib/systemd/system/containerd.service; enabled; preset: enabled)
#      Active: active (running) since Sat 2026-09-12 16:46:21 EDT; 231ms ago
#        Docs: https://containerd.io
#    Main PID: 2528 (containerd)
#       Tasks: 9
#      Memory: 14.9M (peak: 17.8M)
#         CPU: 48ms
#      CGroup: /system.slice/containerd.service
#              └─2528 /usr/bin/containerd

# Sep 12 16:46:21 controlplane containerd[2528]: time="2026-09-12T16:46:21.824220781-04:00" level=info msg="Start cni network conf sync…r default"
# Sep 12 16:46:21 controlplane containerd[2528]: time="2026-09-12T16:46:21.824244426-04:00" level=info msg="Start streaming server"
# Sep 12 16:46:21 controlplane containerd[2528]: time="2026-09-12T16:46:21.824252521-04:00" level=info msg="Registered namespace \"k8s.… with NRI"
# Sep 12 16:46:21 controlplane containerd[2528]: time="2026-09-12T16:46:21.824271843-04:00" level=info msg=serving... address=/run/cont…sock.ttrpc
# Sep 12 16:46:21 controlplane containerd[2528]: time="2026-09-12T16:46:21.824278103-04:00" level=info msg="runtime interface starting up..."
# Sep 12 16:46:21 controlplane containerd[2528]: time="2026-09-12T16:46:21.824359941-04:00" level=info msg="starting plugins..."
# Sep 12 16:46:21 controlplane containerd[2528]: time="2026-09-12T16:46:21.824377406-04:00" level=info msg="Synchronizing NRI (plugin) …ime state"
# Sep 12 16:46:21 controlplane containerd[2528]: time="2026-09-12T16:46:21.824330507-04:00" level=info msg=serving... address=/run/cont…inerd.sock
# Sep 12 16:46:21 controlplane containerd[2528]: time="2026-09-12T16:46:21.824512604-04:00" level=info msg="containerd successfully boo…0.018496s"
# Sep 12 16:46:21 controlplane systemd[1]: Started containerd.service - containerd container runtime.
# Hint: Some lines were ellipsized, use -l to show in full.
```
