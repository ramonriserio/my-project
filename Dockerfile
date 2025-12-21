# Imagem atualizada menor e com menor vulnerabilidades
FROM node:24.12-alpine

# Definindo diretório de trabalho
WORKDIR /app

# Copiando arquivos
COPY src/package.json ./
RUN npm install
COPY src/ .

# Cria diretório de certs e dá permissão ao usuário 'node'
RUN mkdir -p /app/certs && chown -R node:node /app

# Informa que o container rodará na porta 3000
EXPOSE 3000

# Executar como usuário restrito (Segurança)
USER node

# Executando o aplicativo
CMD ["node", "index.js"]