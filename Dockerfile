# Imagem atualizada menor e com menor vulnerabilidades
FROM node:24.12-alpine

# Definindo diretório de trabalho
WORKDIR /app

# Copiando arquivos
COPY scr/package.json ./
RUN npm install
COPY src/ .

# Informando que o container rodará na porta 3000
EXPOSE 3000

# Executando o aplicativo
CMD ["node", "index.js"]