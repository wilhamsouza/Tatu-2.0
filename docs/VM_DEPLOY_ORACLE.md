# Deploy na Oracle VM

Este guia sobe o backend do Tatuzin 2.0 em uma VM Oracle ARM usando Docker Compose e publica a API em `https://api.tatuzin.com.br`.

## O que esta configurado no repositório

- backend empacotado em [backend/Dockerfile](/C:/tatuzin%202.0/backend/Dockerfile)
- inicialização com Prisma em [backend/scripts/docker-entrypoint.sh](/C:/tatuzin%202.0/backend/scripts/docker-entrypoint.sh)
- stack da VM em [docker-compose.vm.yml](/C:/tatuzin%202.0/docker-compose.vm.yml)
- proxy reverso HTTPS em [infra/Caddyfile](/C:/tatuzin%202.0/infra/Caddyfile)
- exemplo de ambiente em [backend/.env.production.example](/C:/tatuzin%202.0/backend/.env.production.example)

## DNS e rede

1. Aponte o registro `A` de `api.tatuzin.com.br` para o IP publico da VM.
2. Abra as portas `80` e `443` na security list da Oracle.
3. Nao exponha a porta `3333` publicamente.

## Preparar a VM

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

Abra uma nova sessao SSH depois de adicionar o usuario ao grupo `docker`.

## Preparar o projeto

```bash
git clone <seu-repo> tatuzin-2.0
cd tatuzin-2.0
cp backend/.env.production.example backend/.env.production
```

Edite `backend/.env.production` e troque obrigatoriamente:

- `JWT_ACCESS_SECRET`
- `JWT_REFRESH_SECRET`
- `CORS_ORIGIN`

## Subir a stack

```bash
docker compose -f docker-compose.vm.yml up -d --build
docker compose -f docker-compose.vm.yml ps
docker compose -f docker-compose.vm.yml logs -f backend
```

O backend vai:

- iniciar em modo `prisma`
- gerar o client Prisma
- criar/sincronizar o schema automaticamente com `prisma db push` se ainda nao houver migrations
- persistir o banco SQLite no volume Docker `tatuzin_sqlite`

## Verificacao

Teste a API:

```bash
curl https://api.tatuzin.com.br/health
```

Resposta esperada:

```json
{"status":"ok","persistence":"prisma"}
```

## Build do app apontando para a API publica

Android APK:

```bash
flutter build apk --release --dart-define=TATUZIN_API_BASE_URL=https://api.tatuzin.com.br
```

Android App Bundle:

```bash
flutter build appbundle --release --dart-define=TATUZIN_API_BASE_URL=https://api.tatuzin.com.br
```

## Backup do banco SQLite

Para exportar o volume do banco:

```bash
mkdir -p backup
docker run --rm \
  -v tatuzin_sqlite:/volume \
  -v "$(pwd)/backup:/backup" \
  alpine sh -c "cp -R /volume/. /backup/"
```

## Observacao importante

Esta stack deixa a VM pronta para operacao inicial em instancia unica. Para a proxima camada de hardening, o passo recomendado e migrar o Prisma para PostgreSQL gerenciado ou PostgreSQL na propria VM.
