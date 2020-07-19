FROM node:8
WORKDIR /var/www/html
COPY ./app /var/www/html
RUN npm install

EXPOSE 8080
CMD [ "node", "server.js" ]
