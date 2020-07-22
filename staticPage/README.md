## This application should be in a different repo so later people don't get blocked by other application pipeline.

## Deployment
### Production and Staging
- Production and staging should be the same way
 - To build the and package this app for use the following step
   - cd to app folder ``cd app``
   - put the correct value for ``SERVICE_NAME`` and ``REG_URL`` in .env file. for example.
   ```
   SERVICE_NAME=staticpages
   REG_URL=asia.gcr.io/project-name/nginx
   ``` 
   - Login to docker container registry  
   ```
   cat credentials.json | docker login -u _json_key --password-stdin https://asia.gcr.io
   ```
   - build and push image to container registry using ``ant``
   ```
   app_version=v0.0.1 ant
   ``` 
   - if your setup correct you will get a message that say ``BUILD SUCCESSFUL`` 
## Deployment
- after we provision the infrastructure, and push the image to container registry we can deploy this app in nginx-static-pages namespace "virtual cluster".   
## Development build
- In development we don't need to push or pull image although it's a good practice to not use the official docker image directly you can customize it and use it if you want.
- To run the code in your machine you should run follow the following
  - from this folder run ``make build``
  - you should see `` hello Iam a index.html `` if you open the application from the browser "localhost"
