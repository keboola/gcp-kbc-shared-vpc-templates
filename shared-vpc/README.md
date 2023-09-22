# Host VPC - Service Project Attachment example
Sample configuration for creating resources in a host project and attaching them to a service project.
This will provision demo host project and one service project.

Created resources:
- Create the network resources within its Shared VPC host network:
  - Main subnet `/24` with secondary ranges named:
    - gke-pods (`/16`)
    - gke-services (`/24`)
  - Regional managed proxy subnet `/24` - for internal load balancer. example terraform resource 
  - IP allocated range for Google Private Service Connect `/24` and VPC peering - it is for mysql databases
- Attach the Keboola service project to the customers Shared VPC network, example terraform resource
- In the Shared VPC host network create firewall rules to allow access to GKE nodes with tag `gke-{KEBOOLA_STACK}` 
  - allow ingress from proxy subnet to GKE nodes
  - allow ingress from google health check IPs (`130.211.0.0/22`, `35.191.0.0/16`) to GKE nodes 
  - allow ingress from GKE control plane to GKE nodes (GKE Control Plane Range)
- Allow IAM roles for service accounts emails from Keboola service project as follows (example terraform resource). Emails are created and shared by Keboola in previous step:
  - allow `roles/compute.networkUser` to the created `Main` subnet for:
    - GKE service account email - `service-{PLATFORM_SERVICE_PROJECT_NUMBER}@container-engine-robot.iam.gserviceaccount.com`
    - Google APIs email - `{PLATFORM_SERVICE_PROJECT_NUMBER}@cloudservices.gserviceaccount.com`
    - Deploy stack email - `stack-deploy@{KEBOOlA_STACK}.iam.gserviceaccount.com`
  - allow `roles/container.hostServiceAgentUser` to the whole host project for:
    - GKE service account email - `stack-deploy@{KEBOOlA_STACK}.iam.gserviceaccount.com`