# CKS: Pod security context - AppArmor

[Back](../README.md)

- [CKS: Pod security context - AppArmor](#cks-pod-security-context---apparmor)
  - [DAC vs MAC](#dac-vs-mac)
  - [AppArmor](#apparmor)
    - [with Kubernetes](#with-kubernetes)
    - [Lab: Security context AppArmor](#lab-security-context-apparmor)
    - [Common Commands](#common-commands)
  - [Lab: apparmor(skip)](#lab-apparmorskip)

---

## DAC vs MAC

- `Discretionary access control (DAC)`
  - a security model where the **owner** of a resource **decides who** can access it and **what actions** they can perform.

- features
  - **Resource Ownership**:
    - The **user** who **creates** or **owns** a file, folder, or database **completely controls** its permissions.
  - **User Discretion**:
    - Owners can **grant, pass on, or revoke** access privileges to **other users or groups**.
  - **Implementation**:
    - Systems often use `Access Control Lists (ACLs)` or traditional **permission bits** (like in UNIX or Windows NTFS) to define these rules.

- Challenges
  - DAC allows programs to **inherit** the full permissions of the user running them.
  - If a user can access sensitive files, any program they run (including malware) can access those same files.

---

- `Mandatory Access Controls`
  - a security model in which access to resources is strictly **regulated by a central authority** based on predefined **security policies**.
  - features
    - Centralized Control
    - use Security Labels
    - Clearance Matching
  - common implementations:
    - SELinux and AppArmor
  - `Confined` (Restricted) and `Unconfined` (Not Restricted)
- `Confined Process`: Everything that process intends to do **must be listed in a profile.**
  - If that capability is not listed in the profile, the process will not be allowed to run that.

---

## AppArmor

- `AppArmor`
  - a **Mandatory Access Control security system** for Linux that **restricts** what individual **programs and applications** are allowed to do.

- How AppArmor Works
  - **Profiles**:
    - Uses plain-text files that **define specific rules** for each program.
  - **Resource Limits**:
    - Controls access to **files**, **network** sockets, system **capabilities**, and inter-process communication.
  - **Kernel Enforcement**:
    - Operates **at the kernel level** so a compromised application cannot bypass its own rules.

- Operating Modes
  - `Enforce Mode`:
    - **Actively blocks unauthorized actions** and **logs** the violations.
  - `Complain Mode`:
    - **Allows** all actions but **logs** policy violations for testing and debugging.
  - `Unconfined Mode`:
    - Runs the application with **standard Linux user permissions without** any `AppArmor` tracking.

---

### with Kubernetes

- ref: https://kubernetes.io/docs/tutorials/security/apparmor/

- allows you to apply `AppArmor profiles` to **Pods and containers**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-apparmor
spec:
  securityContext:
    appArmorProfile:
      type: <profile_type>
```

- `type` key:
  - `Localhost`: a profile pre-loaded on the node (specified by localhostProfile).
  - `RuntimeDefault`: the container runtime's default profile.
  - `Unconfined`: no AppArmor enforcement.

---

- NOTE: if apparmor profile not exists, pod provision fails.

---

### Lab: Security context AppArmor

- ref: https://kubernetes.io/docs/tutorials/security/apparmor/

```sh
ssh node01

# create sample profile on worker node
sudo apparmor_parser -q <<EOF
#include <tunables/global>

profile k8s-apparmor-example-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  file,

  # Deny all file writes.
  deny /** w,
}
EOF

# confirm
sudo aa-status | grep k8s-apparmor-example-deny-write
#    k8s-apparmor-example-deny-write

# deploy pod with apparmor
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-apparmor
spec:
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-apparmor-example-deny-write
  nodeSelector:
    kubernetes.io/hostname: node01
  containers:
  - name: hello
    image: busybox
    command: [ "sh", "-c", "echo 'Hello AppArmor!' && sleep 1h" ]
EOF
# pod/demo-apparmor created

# confirm
kubectl get pod/demo-apparmor
# NAME            READY   STATUS    RESTARTS   AGE
# demo-apparmor   1/1     Running   0          19s

# validate: create a file; deny; exit
kubectl exec -it hello-apparmor -- touch /tmp/file.txt
# touch: /tmp/file.txt: Permission denied
# command terminated with exit code 1
```

---

### Common Commands

| Command                                           | Description                                                            |
| ------------------------------------------------- | ---------------------------------------------------------------------- |
| `aa-enabled`                                      | Verifies if AppArmor is currently active                               |
| `aa-status`                                       | Displays a complete overview of loaded profiles                        |
| `aa-genprof /path/to/executable`                  | Generate a profile for an executable interactively.                    |
| `aa-enforce /path/to/executable`                  | Set the executable's profile to **enforce mode**.                      |
| `aa-complain /path/to/executable`                 | Set the executable's profile to **complain mode** for troubleshooting. |
| `aa-disable /path/to/executable`                  | Completely disables a specific profile.                                |
| `aa-logprof`                                      | Scans log files for apparmor violations                                |
| `aa-cleanprof /path/to/executable`                | Clears out excess log-generated clutter.                               |
| `apparmor_parser -a /etc/apparmor.d/profile.name` | Loads a new profile into the kernel in enforce mode.                   |
| `apparmor_parser -r /etc/apparmor.d/profile.name` | Reload a profile after editing it.                                     |
| `apparmor_parser -R /etc/apparmor.d/profile.name` | Unload a profile from the kernel.                                      |
| `apparmor_parser /etc/apparmor.d/profile.name`    | Load a profile into the kernel.                                        |
| `sudo systemctl reload apparmor`                  | Reloads all profiles configured on the system.                         |

---

## Lab: apparmor(skip)

```sh
# ##############################
# apparmor status
# ##############################
systemctl status apparmor --no-page
# ● apparmor.service - Load AppArmor profiles
#      Loaded: loaded (/usr/lib/systemd/system/apparmor.service; enabled; preset: enabled)
#      Active: active (exited) since Thu 2026-09-10 14:56:47 EDT; 2h 14min ago
#        Docs: man:apparmor(7)
#              https://gitlab.com/apparmor/apparmor/wikis/home/
#    Main PID: 494 (code=exited, status=0/SUCCESS)
#         CPU: 427ms

# Sep 10 14:56:46 controlplane apparmor.systemd[494]: Restarting AppArmor
# Sep 10 14:56:46 controlplane apparmor.systemd[494]: Reloading AppArmor profiles
# Sep 10 14:56:46 controlplane systemd[1]: Starting apparmor.service - Load AppArmor profiles...
# Sep 10 14:56:47 controlplane apparmor.systemd[653]: Warning: found usr.sbin.sssd in /etc/apparmor.d/force-complain, …in mode
# Sep 10 14:56:47 controlplane apparmor.systemd[653]: Warning from /etc/apparmor.d (/etc/apparmor.d/usr.sbin.sssd line…omplain
# Sep 10 14:56:47 controlplane systemd[1]: Finished apparmor.service - Load AppArmor profiles.
# Hint: Some lines were ellipsized, use -l to show in full

aa-enabled
# Yes

sudo aa-status
# apparmor module is loaded.
# 160 profiles are loaded.
# 63 profiles are in enforce mode.
#    /snap/snapd/25935/usr/lib/snapd/snap-confine
#    /snap/snapd/25935/usr/lib/snapd/snap-confine//mount-namespace-capture-helper
#    /snap/snapd/27738/usr/lib/snapd/snap-confine
#    /usr/bin/evince
# ...
```

```sh
# install aa utility
sudo apt install apparmor-utils -y

# create a demo app
tee ~/demo-app.sh <<EOF
#!/bin/bash
touch /tmp/file.txt
echo "New File created"

rm -f /tmp/file.txt
echo "New file removed"
EOF

chmod -v +x ~/demo-app.sh
# mode of '/home/ubuntuadmin/demo-app.sh' changed from 0664 (rw-rw-r--) to 0775 (rwxrwxr-x)

# ##############################
# terminal 1: Generate a new profile(fails, onhold)
# ##############################
sudo aa-genprof ~/demo-app.sh
# Updating AppArmor profiles in /etc/apparmor.d.
# Writing updated profile for /home/ubuntuadmin/demo-app.sh.
# Setting /home/ubuntuadmin/demo-app.sh to complain mode.

# Before you begin, you may wish to check if a
# profile already exists for the application you
# wish to confine. See the following wiki page for
# more information:
# https://gitlab.com/apparmor/apparmor/wikis/Profiles

# Profiling: /home/ubuntuadmin/demo-app.sh

# Please start the application to be profiled in
# another window and exercise its functionality now.

# Once completed, select the "Scan" option below in
# order to scan the system logs for AppArmor events.

# For each AppArmor event, you will be given the
# opportunity to choose whether the access should be
# allowed or denied.

# [(S)can system log for AppArmor events] / (F)inish
# Reading log entries from /var/log/syslog.

# Profile:  /home/ubuntuadmin/demo-app.sh
# Execute:  /usr/bin/touch
# Severity: 3

# (I)nherit / (C)hild / (N)amed / (X) ix On / (D)eny / Abo(r)t / (F)inish

# Profile:  /home/ubuntuadmin/demo-app.sh
# Execute:  /usr/bin/rm
# Severity: unknown

# (I)nherit / (C)hild / (N)amed / (X) ix On / (D)eny / Abo(r)t / (F)inish
# Complain-mode changes:

# Profile:  /home/ubuntuadmin/demo-app.sh
# Path:     /dev/tty
# New Mode: rw
# Severity: 9

#  [1 - include <abstractions/consoles>]
#   2 - /dev/tty rw,
# (A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / Abo(r)t / (F)inish
# Adding include <abstractions/consoles> to profile.

# Profile:  /home/ubuntuadmin/demo-app.sh
# Path:     /etc/ld.so.cache
# New Mode: r
# Severity: 1

#  [1 - /etc/ld.so.cache r,]
# (A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / Abo(r)t / (F)inish
# Adding /etc/ld.so.cache r, to profile.

# Profile:  /home/ubuntuadmin/demo-app.sh
# Path:     /tmp/file.txt
# New Mode: owner w
# Severity: unknown

#  [1 - include <abstractions/user-tmp>]
#   2 - owner /tmp/file.txt w,
# (A)llow / [(D)eny] / (I)gnore / (G)lob / Glob with (E)xtension / (N)ew / Audi(t) / (O)wner permissions off / Abo(r)t / (F)inish
# Adding include <abstractions/user-tmp> to profile.
# Enforce-mode changes:

# = Changed Local Profiles =

# The following local profiles were changed. Would you like to save them?

#  [1 - /home/ubuntuadmin/demo-app.sh]
# (S)ave Changes / Save Selec(t)ed Profile / [(V)iew Changes] / View Changes b/w (C)lean profiles / Abo(r)t
# Writing updated profile for /home/ubuntuadmin/demo-app.sh.

# Profiling: /home/ubuntuadmin/demo-app.sh

# Please start the application to be profiled in
# another window and exercise its functionality now.

# Once completed, select the "Scan" option below in
# order to scan the system logs for AppArmor events.

# For each AppArmor event, you will be given the
# opportunity to choose whether the access should be
# allowed or denied.

# [(S)can system log for AppArmor events] / (F)inish
# Setting /home/ubuntuadmin/demo-app.sh to enforce mode.

# Reloaded AppArmor profiles in enforce mode.

# Please consider contributing your new profile!
# See the following wiki page for more information:
# https://gitlab.com/apparmor/apparmor/wikis/Profiles

# Finished generating profile for /home/ubuntuadmin/demo-app.sh.

# ##############################
# terminal 2: execute the app
# ##############################
~/demo-app.sh
# New File created
# New file removed

# confirm
sudo aa-status | grep demo-app
#    /home/ubuntuadmin/demo-app.sh

ll /etc/apparmor.d/ | grep demo-app
# -rw-------   1 root root   369 Sep 10 18:07 home.ubuntuadmin.demo-app.sh

sudo cat /etc/apparmor.d/home.ubuntuadmin.demo-app.sh
# # Last Modified: Thu Sep 10 18:07:33 2026
# abi <abi/3.0>,

# include <tunables/global>

# /home/ubuntuadmin/demo-app.sh {
#   include <abstractions/base>
#   include <abstractions/bash>
#   include <abstractions/consoles>
#   include <abstractions/user-tmp>

#   /etc/ld.so.cache r,
#   /home/ubuntuadmin/demo-app.sh r,
#   /usr/bin/bash ix,
#   /usr/bin/rm mrix,
#   /usr/bin/touch mrix,

# }
```

- modify

```sh
# before modifying
~/demo-app.sh
# New File created
# New file removed

# modify
echo ping -c2 google.com >> ~/demo-app.sh

# confirm
cat ~/demo-app.sh
# #!/bin/bash
# touch /tmp/file.txt
# echo "New File created"

# rm -f /tmp/file.txt
# echo "New file removed"
# ping -c2 google.com

# execute
~/demo-app.sh
# New File created
# New file removed
# /home/ubuntuadmin/demo-app.sh: line 7: /usr/bin/ping: Permission denied

```

- disable profile

```sh
sudo ln -s /etc/apparmor.d/home.ubuntuadmin.demo-app.sh /etc/apparmor.d/disable/
sudo apparmor_parser -R /etc/apparmor.d/home.ubuntuadmin.demo-app.sh

# confirm
sudo aa-status | grep demo-app
```
