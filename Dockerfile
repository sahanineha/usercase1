FROM node:18-alpine

WORKDIR /app
COPY microservice/ .

RUN npm install
CMD ["npm", "start"]

