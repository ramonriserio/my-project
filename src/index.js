const express = require('express'); // Importa o Express
const https = require('https');     // Módulo HTTPS nativo
const fs = require('fs');           // Módulo de Arquivos para ler os certificados
const app = express();              // Cria uma instância do app
const port = 443;                   // Define a porta do servidor

// Rota GET /status
app.get('/status', (req, res) => {
    // Retorna um JSON com a mensagem
    res.json({
        status: 'OK',
        message: 'Servidor está rodando perfeitamente!',
        timestamp: new Date()
    });
});

// Carregar os certificados (caminhos definidos no Terraform)
const httpsOptions = {
    key: fs.readFileSync('/home/ubuntu/server.key'),
    cert: fs.readFileSync('/home/ubuntu/server.crt')
};

// Iniciar o servidor HTTPS passando as opções e o app express
https.createServer(httpsOptions, app).listen(port, () => {
    console.log(`Aplicação segura rodando em https://localhost:${port}`);
});
