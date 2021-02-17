# momenton-challenge

## Assumptions
- GCP project already exists
- A new VPC network is required to host the application
- 

## Following is done to set up the "training" environment

- Create a custom VPC network in austraila-southeast1 region with two subnets: 
  - web-tier-network
  - app-tier-network
- Create Instance template, defining:
  - Machine type
  - Boot disk size 
  - OS image to use
  - Labels
  - Network Tags
  - Network/Subnetwork
  - Metadata values
  - Startup Script
  - Service Account and its scope
- Create health check for Managed Instance Group (MIG).
- Create MIG for both web tier and app tier.
- Create firewall rules using network Tags. We can also create firewall rules based on Service Account, this is more secure and recommended by Google.
- Create Cloud Router and Cloud NAT so that the internal VMs can communciate with internet for software packages and system updates. Alternatively, this can be achieved in a more secure and controlled way by using either of the following methods or combination of them:
  - using sqid proxy - we can whitelist IP or a CIDR range to allow access to external sites.
  - use packer to create images with all the dependent packages and software and use these images to build VMs. When OS or software update is needed, create a new image using packer and roll out the new image using Rolling Upgrade strategy in the Managed Instance Group.
