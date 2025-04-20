const express = require('express');
const fetch = require('node-fetch');
const app = express();
const port = 3000;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static('public'));

app.post('/api/llm', async (req, res) => {
    try {
        const { prompt, model } = req.body;
        const response = await fetch('http://tunnel:8080/api/llm', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ prompt, model })
        });
        const data = await response.json();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/', (req, res) => {
    res.send(
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title>CloudToLocalLLM</title>
            <style>
                body { margin: 0; font-family: Arial, sans-serif; background: #121212; color: #fff; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
                .container { background: #1e1e1e; padding: 40px; border-radius: 10px; box-shadow: 0 4px 8px rgba(0,0,0,0.3); width: 90%; max-width: 600px; text-align: center; }
                h1 { font-size: 2.5em; margin-bottom: 20px; }
                select, input[type="text"], button { width: 100%; padding: 12px; margin: 10px 0; border: none; border-radius: 5px; font-size: 1em; }
                select, input[type="text"] { background: #2c2c2c; color: #fff; }
                button { background: #6200ea; color: #fff; cursor: pointer; }
                button:hover { background: #3700b3; }
                pre { background: #2c2c2c; padding: 15px; border-radius: 5px; text-align: left; white-space: pre-wrap; min-height: 50px; margin-top: 20px; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>CloudToLocalLLM</h1>
                <select id="model-select">
                    <option value="tinyllama">tinyllama</option>
                    <option value="mistral">mistral</option>
                </select>
                <input type="text" id="prompt" placeholder="Enter your prompt">
                <button onclick="sendPrompt()">Send</button>
                <pre id="response"></pre>
            </div>
            <script>
                async function sendPrompt() {
                    const prompt = document.getElementById('prompt').value;
                    const model = document.getElementById('model-select').value;
                    const responseElement = document.getElementById('response');
                    responseElement.textContent = 'Processing...';
                    try {
                        const response = await fetch('/api/llm', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ prompt, model })
                        });
                        const data = await response.json();
                        responseElement.textContent = data.response || 'No response';
                    } catch (error) {
                        responseElement.textContent = 'Error: ' + error.message;
                    }
                }
            </script>
        </body>
        </html>
    );
});

app.listen(port, () => console.log('Server running on port ' + port));
