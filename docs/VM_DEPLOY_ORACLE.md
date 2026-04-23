# Deploy na Oracle VM

Este guia sobe o backend do Tatuzin 2.0 em uma VM Oracle ARM usando Docker Compose, PostgreSQL e Nginx já instalado no host.

A API pública esperada é `https://api.tatuzin.com.br`.

## O Que Está Configurado No Repositório

- Backend empacotado em [`backend/Dockerfile`](../backend/Dockerfile).
- Inicialização com Prisma em [`backend/scripts/docker-entrypoint.sh`](../backend/scripts/docker-entrypoint.sh).
- Stack de backend + PostgreSQL em [`docker-compose.vm.yml`](../docker-compose.vm.yml).
- Exemplo de Nginx em [`infra/nginx/tatuzin-api.conf`](../infra/nginx/tatuzin-api.conf).
- Exemplo de ambiente em [`backend/.env.production.example`](../backend/.env.production.example).

## DNS E Rede

1. Aponte o registro `A` de `api.tatuzin.com.br` para o IP público da VM.
2. Abra as portas `80` e `443` na security list da Oracle.
3. Não exponha a porta `3333` publicamente.
4. O Compose publica o backend somente em `127.0.0.1:3333`, para o Nginx local fazer proxy.

## Preparar A VM

Exemplo para Ubuntu 24.04 ARM:

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

Abra uma nova sessão SSH depois de adicionar o usuário ao grupo `docker`.

## Preparar O Projeto

```bash
git clone https://github.com/wilhamsouza/Tatu-2.0.git tatuzin-2.0
cd tatuzin-2.0
cp backend/.env.production.example backend/.env.production
```

Edite `backend/.env.production` e troque obrigatoriamente:

- `POSTGRES_PASSWORD`
- a senha dentro de `DATABASE_URL`
- `JWT_ACCESS_SECRET`
- `JWT_REFRESH_SECRET`
- `CORS_ORIGIN`, se houver outro domínio de frontend/admin

Importante: se a senha do PostgreSQL tiver caracteres especiais, use a versão URL encoded no campo `DATABASE_URL`.

## Subir PostgreSQL E Backend

```bash
docker compose --env-file backend/.env.production -f docker-compose.vm.yml up -d --build
docker compose --env-file backend/.env.production -f docker-compose.vm.yml ps
docker compose --env-file backend/.env.production -f docker-compose.vm.yml logs -f backend
```

O backend vai:

- iniciar em modo `prisma`;
- aguardar o PostgreSQL ficar saudável;
- gerar o client Prisma;
- aplicar migrations com `prisma migrate deploy`, se existirem;
- sincronizar o schema com `prisma db push`, enquanto ainda não houver migrations;
- persistir o PostgreSQL no volume Docker `tatuzin_postgres_data`.

## Configurar O Nginx Do Host

Se você já tem Nginx e certificados TLS válidos para `api.tatuzin.com.br`, copie o exemplo:

```bash
sudo cp infra/nginx/tatuzin-api.conf /etc/nginx/sites-available/tatuzin-api.conf
sudo ln -s /etc/nginx/sites-available/tatuzin-api.conf /etc/nginx/sites-enabled/tatuzin-api.conf
sudo nginx -t
sudo systemctl reload nginx
```

Se ainda não tiver certificado TLS para `api.tatuzin.com.br`, gere com Certbot usando o fluxo que você já usa no seu Nginx:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.tatuzin.com.br
```

Depois confirme se os caminhos abaixo existem ou ajuste o arquivo `infra/nginx/tatuzin-api.conf` para apontar para os certificados corretos:

```text
/etc/letsencrypt/live/api.tatuzin.com.br/fullchain.pem
/etc/letsencrypt/live/api.tatuzin.com.br/privkey.pem
```

Então rode:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Verificação

Teste a API:

```bash
curl https://api.tatuzin.com.br/health
```

Resposta esperada:

```json
{"status":"ok","persistence":"prisma"}
```

## Build Do App Apontando Para A API Pública

Android APK:

```bash
flutter build apk --release --dart-define=TATUZIN_API_BASE_URL=https://api.tatuzin.com.br
```

Android App Bundle:

```bash
flutter build appbundle --release --dart-define=TATUZIN_API_BASE_URL=https://api.tatuzin.com.br
```

## Backup Do PostgreSQL

Exemplo de dump lógico:

```bash
docker compose --env-file backend/.env.production -f docker-compose.vm.yml exec -T postgres \
  sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > backup-tatuzin.sql
```

Para restaurar:

```bash
cat backup-tatuzin.sql | docker compose --env-file backend/.env.production -f docker-compose.vm.yml exec -T postgres \
  sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"'
```

## Observação Importante

Esta stack deixa a VM pronta para operação inicial em instância única, usando PostgreSQL em container local e Nginx no host.

Para escalar para múltiplas VMs ou alta disponibilidade, migre `DATABASE_URL` para um PostgreSQL gerenciado ou cluster PostgreSQL dedicado.
