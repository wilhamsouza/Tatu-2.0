# Tatuzin 2.0

Tatuzin 2.0 é uma plataforma modular para lojas de roupas, com PDV mobile offline-first, ERP/CRM server-first e sincronização resiliente entre app e backend.

Este repositório corresponde ao projeto GitHub `wilhamsouza/Tatu-2.0`.

## Visão Geral

- App Flutter offline-first na raiz do projeto, com SQLite como fonte local do PDV.
- Backend Node.js + TypeScript em [`backend/`](backend/), com Express, Prisma e JWT.
- Sync Bridge com outbox, inbox, retries, idempotência e updates incrementais.
- ERP e CRM server-first, seguindo o documento mestre do Tatuzin 2.0.
- Deploy inicial para Oracle VM documentado em [`docs/VM_DEPLOY_ORACLE.md`](docs/VM_DEPLOY_ORACLE.md).

## Estrutura

```text
lib/
  core/
  modules/
backend/
  prisma/
  src/
  tests/
docs/
infra/
```

## Como Rodar

### App Flutter

```bash
flutter pub get
flutter run
```

Perfis demo disponíveis no login:

- `admin@tatuzin.app`
- `manager@tatuzin.app`
- `seller@tatuzin.app`
- `cashier@tatuzin.app`
- `crm@tatuzin.app`

Senha padrão:

```text
tatuzin123
```

### Backend

```bash
cd backend
npm install
npm run dev
```

Para usar Prisma localmente:

```bash
cp .env.example .env
npm run prisma:generate
npm run prisma:push
```

## Validação

```bash
flutter analyze
flutter test
cd backend && npm test
cd backend && npm run build
```

## Deploy

A stack inicial de VM usa Docker Compose e Caddy para publicar a API em `https://api.tatuzin.com.br`.

Consulte [`docs/VM_DEPLOY_ORACLE.md`](docs/VM_DEPLOY_ORACLE.md).

Arquivos sensíveis reais, como `.env`, `.env.production`, bancos locais, builds e caches, não devem ser versionados.
