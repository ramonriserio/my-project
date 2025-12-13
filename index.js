const express = require('express'); // Importa o Express
const app = express();              // Cria uma instância do app
const port = 3000;                  // Define a porta do servidor

// Rota GET /status
app.get('/status', (req, res) => {
    // Retorna um JSON com a mensagem
    res.json({
        status: 'OK',
        message: 'Servidor está rodando perfeitamente!',
        timestamp: new Date()
    });
});

// Inicia o servidor
app.listen(port, () => {
    console.log(`Aplicação rodando em http://localhost:${port}`);
});