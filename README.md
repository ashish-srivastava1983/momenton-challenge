# momenton-challenge

## Assumptions
- GCP project already exists
- A new VPC network is required to host the application
- Oragnization Policies are set. For example, to prevent VMs coming up with externap IP addresses, trsuted image policy etc.

## Design Overview

Refer to the image Design_Overview.png for Design overview. 

## Limited Release 

### Following needs to be done to provision "training" and "production" environments for limited release.

- Create a custom VPC network with two subnets in australia-southeast1 region.
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
- Use shielded VMs to protect against rootkits and bootkits.
- Create health check for Managed Instance Group (MIG).
- Create MIG for both web tier and app tier.
  - Regional MIG
  - For limited release keep the target size to 1. When applciation needs to be fully pubic, this count can be increased to scale the web tier in region.
- Create firewall rules using network Tags. We can also create firewall rules based on Service Account, this is more secure and recommended by Google.
- Create Cloud Router and Cloud NAT so that the internal VMs can communciate with internet for software packages and system updates. Alternatively, this can be achieved in a more secure and controlled way by using either of the following methods or combination of them:
  - using sqid proxy - we can whitelist IP or a CIDR range to allow access to external sites.
  - use packer to create images with all the dependent packages and software and use these images to build VMs. When OS or software update is needed, create a new image using packer and roll out the new image using Rolling Upgrade strategy in the Managed Instance Group.
- Create HTTP(S) Load Balancer for incoming traffic to the web tier.
  - Create a Backend Service
  - Add MIG as a backend to the Backend Service
  - Create a HTTP health check
  - Create a URL Map
  - Create a Target HTTP Proxy
  - Create a Global Forwarding rule
- To protect applciation from DDoS attack or SQL injection attacks, we can use Cloud Armour. 
- If requried, we can also use Cloud Identity Aware Proxy (IAP) to control authentication and authorization to the applciation.
- Create an Internal Load Balancer (ILB) to receive traffic from web tier VM and distribute teh traffic to app-tier VMs.
- Create neessary firewall rules to allow web-tier VMs to send traffic to app-tier VMs via ILB. 

## Full Public Release

### Requirements for full Public release
- Availability - 24/7
- Sub second response time
- Tolerate single erver failures
- Scalability 

### Following updates will be required for full public release
- Extend the VPC network and create new subnet(s) in new region(s).
- Increase the target nodes in MIGs appropriately.
- For Web tier, create another Backend Service with MIG as a backed in another region as required.
- Might need to craete a new ser of app-tier MIG and ILB in the new region.
- Enable Cloud CDN with HTTP(s) Load balancer to serve static content faster and closer to the end user.
- May explore the option of Cloud SQl (regional with read replicas) or Cloud Spanner (global SQL database) for data storage at scale and to achieve high availability and performance.
- Cost needs to be considered carefully during scaling up of the environment.


