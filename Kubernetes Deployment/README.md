##Kubernetes Deployment with Terraform##

Terraform is a powerful tool for deploying Infrastructure as Code (IaC).

When it comes to Kubernetes clusters, creating deployments and services using raw manifest files can be inefficient and error-prone. Managing resources manually with kubectl apply lacks state awareness, making it difficult to track changes, manage dependencies, and ensure consistency across environments.

Terraform simplifies this process by offering:

1. State management: Tracks the infrastructure state, preventing drift and unintended changes.
2. Dependency resolution: Ensures that resources are created and updated in the correct order.
3. Multi-cloud integration: Allows provisioning Kubernetes resources alongside cloud infrastructure (EKS, GKE, AKS, etc.).
4. Change previews: Provides a terraform plan to preview changes before applying them, reducing the risk of misconfigurations.
5. Reusability: Enables modular, reusable configurations for managing multiple environments efficiently.
6. By using Terraform to manage Kubernetes resources, we achieve a more scalable, automated, and predictable deployment process.

In this setup, we deploy a simple Kubernetes Deployment with 4 replicas and a NodePort Service to expose the application externally.

![alt text](<Screenshot 2025-02-15 at 11.57.25 AM.png>)