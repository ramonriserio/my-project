# Implementação de CI/CD de infraestrutura e aplicação Node.js containerizada com GitHub Actions
Este documento apresenta a documentação técnica da infraestrutura, as decisões arquiteturais adotadas e o registro dos desafios superados durante a implementação do desafio proposto.

## **🔗 Entregáveis e Acesso**

- **Repositório GitHub:** https://github.com/ramonriserio/my-project.git
- **Ambiente de Staging (Homologação):** https://98.90.199.108/status
- **Ambiente de Produção:** https://54.227.105.228/status

**⚠️ Observação de Segurança:** Como a solução utiliza certificados autoassinados (detalhes na seção 3), seu navegador exibirá um alerta de segurança. É necessário aceitar o risco para visualizar o JSON de retorno da API.

**⚠️ Política de Retenção:** Os ambientes permanecerão ativos por **7 dias**. Após esse período, a automação de desprovisionamento será executada para evitar custos adicionais na AWS.

## **1. Visão Geral e Stack Tecnológica**

A aplicação consiste em um serviço web desenvolvido em **Node.js**, containerizado via **Docker** e orquestrado em instâncias **AWS EC2**. O objetivo é servir uma API segura (HTTPS) com endpoints de monitoramento de saúde.

**Stack Utilizada:**

- **Cloud Provider:** AWS (Região us-east-1).
- *Decisão:* A escolha pela AWS baseou-se no domínio prévio sobre a plataforma, permitindo focar os esforços na complexidade da automação CI/CD.
- **IaC (Infraestrutura como Código):** Terraform (com Backend remoto S3 + DynamoDB Lock) .
- **CI/CD:** GitHub Actions.
- **Aplicação:** Node.js (Express) + Docker.

## **2. Arquitetura de Ambientes (Staging vs. Produção)**

Para garantir segurança e confiabilidade, os ambientes de Staging e Produção foram projetados com isolamento lógico total, seguindo as melhores práticas de segregação de recursos .

### **Tabela Comparativa de Ambientes**

| **Recurso** | **Staging (Homologação)** | **Produção** |
| --- | --- | --- |
| **VPC (Rede)** | Isolada (Ex: 10.0.0.0/16) | Isolada (Ex: 10.1.0.0/16) |
| **Instância EC2** | dev-projeto-node-ec2 (t3.micro/small) | prod-projeto-node-ec2 (t3.medium/large) |
| **Acesso (Security Group)** | Portas 80, 443 e 22 (SSH Restrito à equipe) | Portas 80, 443 (Público) e 22 (SSH Restrito) |
| **Branch de Origem** | develop | main |
| **Tags AWS** | Environment=Staging | Environment=Production |

<img width="555" height="485" alt="image" src="https://github.com/user-attachments/assets/bd6361f8-0521-4575-9763-5a7068360b1a" />


## **3. Decisões de Segurança e HTTPS**

### **Estratégia de Criptografia (TLS)**

Para implementar HTTPS, foi necessário avaliar o cenário de teste versus o cenário ideal de produção:

1. **Cenário Ideal (ALB + ACM):** Em um ambiente produtivo definitivo, a solução recomendada seria o uso de *Application Load Balancer* integrado ao *AWS Certificate Manager*. Isso garante escalabilidade e confiança pública, mas exige a posse de um **domínio válido (FQDN)**.
2. **Cenário Adotado (Certificado Autoassinado):** Como o acesso aos ambientes do desafio é realizado diretamente via Endereço IP (sem domínio registrado), optou-se por gerar certificados autoassinados (Self-Signed) e montá-los via volumes no Docker (/usr/src/app/certs/) . Esta abordagem cumpre o requisito técnico de criptografia em trânsito e viabiliza os testes imediatos.

### **Gestão de Segredos**

- Credenciais sensíveis (AWS Access Keys, SSH Keys, Docker Hub Credentials) são armazenadas exclusivamente no **GitHub Secrets** .
- O acesso à AWS é realizado preferencialmente via OIDC (OpenID Connect) ou usuários IAM com princípio do menor privilégio .

## **4. Evolução do CI/CD e Desafios Superados**

A implementação das pipelines de automação representou o maior desafio técnico deste projeto, consumindo cerca de dois terços do tempo disponível.

### **O Desafio da Orquestração**

Inicialmente, os workflows foram configurados utilizando o gatilho workflow_run. Contudo, identificou-se uma limitação crítica:

- **O Problema:** O workflow_run sempre utiliza a definição de workflow presente na branch padrão (main), independentemente da branch onde ocorreu o disparo original. Isso impossibilitava testar alterações de infraestrutura na branch develop antes do merge.

### **A Solução: Reusable Workflows**

Após extensa pesquisa e depuração, a arquitetura de CI/CD foi refatorada para utilizar **workflow_call**.

- **Estrutura Simplificada:** O projeto foi consolidado em apenas dois arquivos principais: um para infraestrutura (infra.yml) e outro para aplicação (app.yml).
- **Resultado:** O workflow de infraestrutura agora chama o workflow de aplicação diretamente, passando os contextos e inputs corretos. Essa mudança garantiu que deploys em Staging refletissem fielmente o código da branch de desenvolvimento.

## **5. Operação**

### **Automação de Desprovisionamento (Destroy)**

Para facilitar a limpeza do ambiente e evitar cobranças indesejadas, foi implementado um mecanismo de controle via código.

- **Arquivo de Controle:** infra/destroy_config.json.
- **Como funciona:** Para destruir a infraestrutura de um ambiente específico, basta alterar o valor da chave correspondente (ex: "develop": true) no arquivo JSON e realizar o push. O pipeline do Terraform detectará a flag e executará o terraform destroy automaticamente.

## **6. Estratégia de Rollback Funcional**

Aqui está o seu texto formatado profissionalmente em Markdown, pronto para ser copiado para um arquivo `.md` ou documentação.

---

### 1. A Estratégia Geral

O problema de usar apenas a tag `:latest` é que, quando você sobe uma versão quebrada, a versão boa é sobrescrita no registro (Docker Hub).

### 🌟 A Regra de Ouro

Toda imagem deve ter duas tags no momento do build:

* `:latest` (para referência fácil).
* `:sha-xyz123` (o hash do commit do Git, tornando-a imutável).

### Fluxo de Rollback

Se a produção quebrar, você não corrige o código correndo. Você dispara um **Workflow Manual de Rollback** que pega a imagem `sha-xyz-versao-anterior` e a coloca no ar em segundos.

---

### 2. Implementação Técnica

### Passo A: Ajustar o Build para gerar Tags Imutáveis

No seu `app.yml` (Docker Workflow), altere o passo de build para gerar uma tag única baseada no commit.

```yaml
      - name: Build and Push Docker image
        run: |
          # Tag LATEST
          docker build -t ${{ secrets.DOCKER_USERNAME }}/projeto-node-app:latest .
          docker push ${{ secrets.DOCKER_USERNAME }}/projeto-node-app:latest
          
          # Tag SHA (Imutável)
          docker build -t ${{ secrets.DOCKER_USERNAME }}/projeto-node-app:${{ github.sha }} .
          docker push ${{ secrets.DOCKER_USERNAME }}/projeto-node-app:${{ github.sha }}

```

### Passo B: Criar o Workflow de Rollback Dedicado

Crie um arquivo `.github/workflows/rollback.yml`. Esse workflow não constrói nada, ele apenas conecta na EC2 e força uma versão específica.

```yaml
name: Manual Rollback

on:
  workflow_dispatch:
    inputs:
      target_tag:
        description: 'Tag da imagem para rollback (ex: sha-a1b2c3d ou uma versão v1.0.0)'
        required: true
        default: 'latest'

jobs:
  rollback-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::368453405930:role/projeto-node-ec2-vpc
          aws-region: us-east-1

      - name: Get EC2 Public IP
        id: get_ip
        run: |
          # Mesma lógica do seu workflow principal para achar o IP
          if [[ "${{ github.ref_name }}" == "main" ]]; then
             TARGET_NAME="prod-projeto-node-ec2"
          else
             TARGET_NAME="dev-projeto-node-ec2"
          fi
          
          IP=$(aws ec2 describe-instances \
            --filters "Name=tag:Name,Values=$TARGET_NAME" \
                      "Name=instance-state-name,Values=running" \
            --query "Reservations[*].Instances[*].PublicIpAddress" \
            --output text)
          
          echo "public_ip=$IP" >> $GITHUB_OUTPUT

      - name: Execute Rollback via SSH
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ steps.get_ip.outputs.public_ip }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            echo "🚨 INICIANDO ROLLBACK PARA VERSÃO: ${{ inputs.target_tag }} 🚨"
            
            # Login para garantir acesso
            echo "${{ secrets.DOCKER_PASSWORD }}" | docker login -u "${{ secrets.DOCKER_USERNAME }}" --password-stdin
            
            # Baixa a versão específica (pode ser antiga)
            docker pull ${{ secrets.DOCKER_USERNAME }}/projeto-node-app:${{ inputs.target_tag }}
            
            # Para e remove o atual
            docker stop myapp || true && docker rm myapp || true
            
            # Sobe a versão antiga
            docker run -d \
              --name myapp \
              --restart unless-stopped \
              -p 80:3000 \
              -p 443:443 \
              -v /home/ubuntu/server.crt:/usr/src/app/certs/server.crt \
              -v /home/ubuntu/server.key:/usr/src/app/certs/server.key \
              -e SSL_KEY_PATH=/usr/src/app/certs/server.key \
              -e SSL_CERT_PATH=/usr/src/app/certs/server.crt \
              ${{ secrets.DOCKER_USERNAME }}/projeto-node-app:${{ inputs.target_tag }}

```

---

### 3. Como funciona no dia a dia?

### Cenário 1: Aplicação Quebrou (Bug no código)

1. Você fez push, o pipeline rodou, deployou a imagem `:latest` (que corresponde ao commit `abcdef`).
2. O site caiu ou está com erro crítico.
3. **Ação:** Você vai na aba "Actions" do GitHub, seleciona "Manual Rollback".
4. No campo `target_tag`, você cola o hash do commit anterior que estava funcionando (ex: `987654`).
5. Clique em "Run workflow".
6. Em 30 segundos, a EC2 baixa a imagem velha e sobe. O serviço volta.

### Cenário 2: Infraestrutura Quebrou (Terraform)

Se você alterou o Terraform (ex: mudou Security Group e bloqueou a porta 80):

1. O Rollback de Docker acima não vai adiantar, pois a rede está bloqueada.
2. **Ação:** Reverter o Commit no Git.
* `git revert HEAD` (cria um commit novo que desfaz as mudanças).
* `git push`.


3. O workflow **Terraform Workflow** vai rodar automaticamente, detectar a mudança (volta ao estado anterior) e aplicar o `terraform apply` para corrigir a infra.

---

### Resumo das Vantagens dessa Estratégia

* **Velocidade:** Reverter via imagem Docker (`docker run tag-antiga`) leva segundos. Reverter via pipeline completo (buildar de novo) leva minutos.
* **Segurança:** Você não mexe no código nem gera builds novos num momento de pânico. Você usa um artefato (imagem) que você *sabe* que funcionava ontem.
* **Separação de Responsabilidades:** Problema de código resolve com Docker. Problema de configuração AWS resolve com Git Revert do Terraform.

## 7. Estratégia de Logs e Observabilidade

Embora uma stack completa de monitoramento (APM) não esteja no escopo inicial, a aplicação e o processo de deploy foram estruturados para garantir auditabilidade e rastreabilidade mínima.

### A. Logs da Aplicação (Container)
* **Padrão de Log:** A aplicação Node.js segue a prática *Twelve-Factor App*, enviando logs estruturados diretamente para a saída padrão (`stdout` e `stderr`).
* **Captura:** O Docker Daemon intercepta esses fluxos e os armazena localmente na instância EC2 (driver `json-file`).
* **Como Acessar (Troubleshooting):**
    ```bash
    # Acesso via SSH
    docker logs -f myapp --tail 100
    ```

### B. Observabilidade do Deploy (CI/CD)
* **Rastreabilidade:** Todo o histórico de builds e deploys é mantido no **GitHub Actions**.
* **Detalhamento:** Logs detalhados de cada etapa (Setup, Build, Login, Push, Deploy). Em caso de falha, é possível identificar exatamente a linha do erro (ex: falha na conexão SSH ou sintaxe do Dockerfile).

### C. Monitoramento de Saúde (Health Check)
* **Liveness Probe:** Endpoint `/status`.
* **Função:** Permite validação externa para confirmar se a API está capaz de processar requisições.
* **Infraestrutura:** Métricas básicas da AWS (CPU, Rede e Status Checks) via console EC2.

### D. Roadmap (Futuro)
Para um ambiente produtivo de larga escala, a estratégia evoluiria para:
1.  **Centralização:** CloudWatch Agent para envio de logs.
2.  **Métricas:** Prometheus para uso de memória do Node.js.
3.  **Alertas:** SNS para notificar falhas no health check.
