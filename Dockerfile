FROM node:18

WORKDIR /app
COPY microservice/ .
EXPOSE 3000
RUN npm install
CMD ["node", "index.js"]

