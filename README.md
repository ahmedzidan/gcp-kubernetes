## New Structure 
![](image/infra-1-1.png)

### Resources
- **Cloud DNS**: DNS with zone for app.com

- **Http/Https LB** : load balancer to redirect the traffic based on the url.
 
- **Private GKE** contains two virtual clusters "nameSpaces"
- **virtual cluster** for serving the backend processing.
- **virtual cluster** for serving the static pages.

- **Private subnet** For GKE nodes.

- **NAT GATEWAY** for the nodes to be able to connect to the internet without having public IP.

- **Redis** keeps clients connectivity state.

- **MySql** keeps user accounts

- **Beats** ElasticSearch beats it can be any log we want to have.

- **Redis or kafka** as a queue for logs.

- **Logstash** : log stash to store the log to ES cluster.

- **ElasticSearch Cluster** : Cluster to keep the log.

- **Kibana** : for visualization.

### provision infrastructure
- The structure of my files like the following. 
- ``provider.tf``: contains the provider info in our case is GCP.
- ``main.tf``: call modules, and data-sources to create all resources.
- ``variables.tf``: contains declarations of variables used in main.tf
- ``outputs.tf``: contains outputs from the resources created in main.tf
- ``locals.tf``: contains the locals values.
- To provision infrastructure and deploy a sample App
  1- ``cd provision/production``
  2- ``terraform init -backend-config="bucket=remote-bucket-name"`` 
  2- ``terraform apply -auto-approve -var="app_env=production" -var="project_id=testproject-id" `` 
  3- You should get the LB public ip.
  4- visit the public ip for example http://35.201.104.234/ you should see "Hello, world!"
  4- visit the public ip for example http://35.201.104.234/api you should see "Hello Kubernetes!"
### High availability in GKE cluster.

- The cluster can be Multi-zonal cluster, so it will be high available in all the zone in the region. 

- However it's still has the single point of failure as it will have one master node.

- Optional to make the cluster ``Regional clusters``

### Auto Scaling in GKE cluster.

- To make the application Scalable we should enable the GEK cluster autoscaler.

- We can define the min and max nodes required per each cluster. 


### Security

- We will create a private cluster so no one will be able to access it from outside the vpc. 

- All nodes will not have public ip, so we defined A NAT gateway to make the nodes able to connect to the internet.

- LB has Google Cloud Armor(WAF, ip/allow/deny, custom rules) by default we can secure the application from DDoS and targeted web-based attacks. 

- Enable ``Container Analysis`` for performs vulnerability scans for images in Container Registry.


### Application environment containers.
- please read it from inside the application folder 
- [nginx static pages](https://github.com/ahmedzidan/gcp-kubernetes/tree/master/staticPage)
- [nodejs api](https://github.com/ahmedzidan/gcp-kubernetes/tree/master/nodeJsApi)

### Application deployment.

- First step we need to build and package the docker images.

- Push the image to ``Container Registry`` with a specific tag. 

- At this time we can scan the image and decide if we want to release it or not.

- After that we deploy using canary deployment. 

### Migration plan to cloud SQL.

- First we need to create a Cloud SQL for SQL Server instance.

- As well as create a Cloud Storage bucket.

- Connect to mssql, create a backup of your database, and upload the backup database to Cloud Storage.

- Import the backup file (from cloud storage) to the Cloud SQL database.

- After that we can validate the data and see if it's imported successfully or not.
