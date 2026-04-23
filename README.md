# Tatuzin 2.0

Fundação inicial do Tatuzin 2.0 construída a partir do documento mestre de implementação.

O repositório foi organizado como um monorepo com duas frentes:

- app Flutter offline-first na raiz do projeto
- backend Node.js + TypeScript em [`backend/`](/C:/tatuzin%202.0/backend)

## O que já está implementado

### App Flutter

- estrutura modular refletindo `core/`, `modules/pdv`, `modules/erp`, `modules/crm`, `modules/settings` e `modules/dashboard`
- `Riverpod` para estado e `GoRouter` para navegação
- bootstrap de SQLite local com tabelas base de PDV, sync, sessão e catálogo materializado
- persistência de sessão local com `FlutterSecureStorage` + tabela `user_session`
- identidade de device persistida localmente
- papéis básicos e proteção de módulos na UI
- domínio inicial de `PaymentTerm` com regras de nota, saldo em aberto e baixa

### Backend

- Express + TypeScript com módulos iniciais de `auth`, `devices`, `sales`, `sync` e `catalog`
- JWT para access token e refresh token
- middlewares de autenticação, tenancy e roles
- ingestão idempotente de vendas por `operationId`
- criação de `ReceivableNote` quando a venda usa pagamento em nota
- endpoint de sync outbox para o fluxo inicial do PDV
- `schema.prisma` inicial com entidades centrais do domínio

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
```

Detalhes arquiteturais adicionais estão em [docs/ARCHITECTURE.md](/C:/tatuzin%202.0/docs/ARCHITECTURE.md).

## Como rodar

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

Se quiser evoluir o banco Prisma depois:

```bash
cp .env.example .env
npm run prisma:generate
```

## Validação atual

```bash
flutter analyze
flutter test
cd backend && npm test
cd backend && npm run build
```

## Próximos passos recomendados

1. Implementar catálogo local consultável no PDV com busca por nome e barcode.
2. Criar carrinho, checkout e transação local completa de venda.
3. Materializar `sync_outbox` e `sync_inbox` com scheduler e retry exponencial.
4. Ligar o app Flutter ao backend real em vez do repositório demo de auth.
5. Evoluir `sales` e `sync` para persistência via Prisma.
