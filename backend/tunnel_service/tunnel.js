const express = require('express');
const app = express();
const PORT = 8080;

app.get('/api/llm', (req, res) => {
  res.json({ status: 'Tunnel is active', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.send('Tunnel service is running.');
});

app.listen(PORT, () => {
  console.log(`Tunnel service listening on port ${PORT}`);
}); 