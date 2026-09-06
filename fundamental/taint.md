# CKS: Fundamental - Taint

[back](../README.md)

- [CKS: Fundamental - Taint](#cks-fundamental---taint)
  - [Taint](#taint)
  - [toleration](#toleration)

---

## Taint

- `taint`
  - node property to repel certain pods

```sh
kubectl taint node node_name key=value:effect
```

| Effects          | Description                                                                           |
| ---------------- | ------------------------------------------------------------------------------------- |
| NoSchedule       | Prevents scheduling of **new** pods on the node unless they tolerate the taint.       |
| PreferNoSchedule | **Tries to avoid** scheduling new pods on the node, but does not enforce it strictly. |
| NoExecute        | **Evicts** existing pods and prevents new pods from being scheduled on the node.      |

---

## toleration

- `toleration`
  - a pod property to schedule the pod to a node with `taint`.

```yaml
spec:
  tolerations:
    - key: "key_name"
      operator: ""
      effect: ""
```

- operator:
  - `Exists`: no value
  - `Equal`: equal value
  - `Gt`: matches when the taint value is greater than the toleration value.
  - `Lt`: matches when the taint value is less than the toleration value
