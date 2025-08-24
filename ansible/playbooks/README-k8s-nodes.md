# Kubernetes Worker Node Join Process

## Overview

The `k8s-nodes.yml` playbook handles joining worker nodes to the Kubernetes cluster after the control plane has been initialized by the manager node.

## Process Flow

1. **Pre-join Checks**
   - Verify if node is already part of a cluster
   - Get join information from the manager node
   - Test connectivity to the API server

2. **Node Join**
   - Execute kubeadm join command with retry logic
   - Verify kubelet configuration is created
   - Wait for kubelet service to be active

3. **Post-join Configuration**
   - Apply node labels if specified in `node_labels` variable
   - Apply node taints if specified in `node_taints` variable
   - Wait for node to reach Ready state

4. **Cluster Verification**
   - Verify all expected nodes are present
   - Test pod scheduling on worker nodes
   - Check network pod distribution
   - Validate cluster component status

## Configuration Variables

### Required Variables (from group_vars/all.yml)
- `join_retry_count`: Number of retries for join operation (default: 3)
- `node_ready_timeout`: Timeout for node to become ready (default: 600s)

### Optional Variables
- `node_labels`: Dictionary of labels to apply to nodes
- `node_taints`: List of taints to apply to nodes

### Example Configuration
```yaml
# Apply labels to worker nodes
node_labels:
  node-type: worker
  environment: production
  
# Apply taints (if needed)
node_taints:
  - "workload=batch:NoSchedule"
```

## Dependencies

This playbook requires:
1. Manager node must be initialized first (`k8s-manager.yml`)
2. Common Kubernetes setup completed (`k8s-common.yml`)
3. Join command and tokens available from manager node

## Error Handling

- Retries join operation up to `join_retry_count` times
- Validates kubelet configuration after join
- Checks node connectivity before attempting join
- Provides detailed error messages for troubleshooting

## Verification

The playbook includes comprehensive verification:
- Node readiness checks
- Cluster membership validation
- Pod scheduling tests
- Network connectivity tests
- Component status checks

## Usage

This playbook is typically run as part of the main `site.yml` orchestration:

```bash
ansible-playbook -i inventory/hosts site.yml
```

Or run independently after manager initialization:

```bash
ansible-playbook -i inventory/hosts playbooks/k8s-nodes.yml
```