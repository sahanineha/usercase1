// index.js
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('Hello from your EKS microservice!');
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});

