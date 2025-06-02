const express = require('express');
const app = express();
const port = 80;

// Health check route
app.get('/', (req, res) => {
  res.send('Hello from the microservice! 🚀');
});

// Optional: Health endpoint
app.get('/health', (req, res) => {
  res.send('OK');
});

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});

