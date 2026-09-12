# CKS setup: worker node install containerd

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
#      Active: active (running) since Sat 2026-09-12 17:52:47 EDT; 258ms ago
#        Docs: https://containerd.io
#    Main PID: 2441 (containerd)
#       Tasks: 7
#      Memory: 14.0M (peak: 17.2M)
#         CPU: 47ms
#      CGroup: /system.slice/containerd.service
#              └─2441 /usr/bin/containerd

# Sep 12 17:52:47 node01 containerd[2441]: time="2026-09-12T17:52:47.354882107-04:00" level=info msg="Start recovering state"
# Sep 12 17:52:47 node01 containerd[2441]: time="2026-09-12T17:52:47.355062888-04:00" level=info msg="Start event monitor"
# Sep 12 17:52:47 node01 containerd[2441]: time="2026-09-12T17:52:47.355072849-04:00" level=info msg="Start cni network conf syncer for default"
# Sep 12 17:52:47 node01 containerd[2441]: time="2026-09-12T17:52:47.355082064-04:00" level=info msg="Start streaming server"
# Sep 12 17:52:47 node01 containerd[2441]: time="2026-09-12T17:52:47.355087966-04:00" level=info msg="Registered namespace \"k8s.io\" with NRI"
# Sep 12 17:52:47 node01 containerd[2441]: time="2026-09-12T17:52:47.355093958-04:00" level=info msg="runtime interface starting up..."
# Sep 12 17:52:47 node01 containerd[2441]: time="2026-09-12T17:52:47.355097512-04:00" level=info msg="starting plugins..."
# Sep 12 17:52:47 node01 containerd[2441]: time="2026-09-12T17:52:47.355105617-04:00" level=info msg="Synchronizing NRI (plugin) with c…ime state"
# Sep 12 17:52:47 node01 containerd[2441]: time="2026-09-12T17:52:47.355310624-04:00" level=info msg="containerd successfully booted in 0.019227s"
# Sep 12 17:52:47 node01 systemd[1]: Started containerd.service - containerd container runtime.
# Hint: Some lines were ellipsized, use -l to show in full.
```
