# Kubernetes Admission Controller with OPA

To use OPA as an admission controller in Kubernetes:

1. Deploy OPA as a webhook
2. Deploy OPA service with policies mounted as ConfigMap
3. Use kube-mgmt to replicate Kubernetes data into OPA
