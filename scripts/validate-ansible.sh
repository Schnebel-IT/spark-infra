#!/bin/bash

# Ansible playbook validation script
set -e

echo "Validating Ansible playbooks..."

# Check if ansible-playbook is available
if ! command -v ansible-playbook &> /dev/null; then
    echo "Warning: ansible-playbook not found. Please install Ansible to run full validation."
    exit 1
fi

# Validate syntax of all playbooks
echo "Checking syntax of k8s-manager.yml..."
ansible-playbook --syntax-check ansible/playbooks/k8s-manager.yml -i ansible/inventory/hosts

echo "Checking syntax of k8s-common.yml..."
ansible-playbook --syntax-check ansible/playbooks/k8s-common.yml -i ansible/inventory/hosts

echo "Checking syntax of k8s-nodes.yml..."
ansible-playbook --syntax-check ansible/playbooks/k8s-nodes.yml -i ansible/inventory/hosts

echo "Checking syntax of site.yml..."
ansible-playbook --syntax-check ansible/site.yml -i ansible/inventory/hosts

echo "All Ansible playbooks passed syntax validation!"