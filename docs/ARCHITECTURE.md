# Arquitetura Inicial

Este repositório já reflete a direção principal do documento mestre:

- `PDV Local` como camada offline-first no app
- `ERP Cloud` e `CRM Cloud` como camadas server-first
- `Sync Bridge` como subsistema independente
- `Core Platform` centralizando auth, sessão, tenancy, roles, device identity e banco local

## Decisões materializadas

### App Flutter

- `lib/core/database/app_database.dart` inicializa o SQLite e cria as tabelas mínimas descritas no documento.
- `lib/core/auth/` concentra sessão, tokens, bootstrap e persistência segura.
- `lib/core/permissions/` e `lib/core/tenancy/` já separam papéis e contexto de empresa.
- `lib/modules/pdv/payments/domain/entities/payment_term.dart` implementa a regra central de nota com `dueDate`, saldo e transição de status.

### Backend

- `backend/src/core/auth/` contém JWT e contexto autenticado.
- `backend/src/core/tenancy/` garante presença de `companyId`.
- `backend/src/core/permissions/` protege rotas por papel.
- `backend/src/modules/sales/` já trata venda e criação de `ReceivableNote`.
- `backend/src/modules/sync/` recebe lotes do outbox do app com idempotência por `operationId`.

## Escopo efetivamente coberto nesta fundação

- Fase 1 quase completa em estrutura e bootstrap
- parte da Fase 2 antecipada no domínio de pagamento em nota
- parte da Fase 3 antecipada no backend com `sync/outbox`

## Lacunas deliberadas

As seguintes partes ainda estão apenas preparadas estruturalmente, sem fluxo completo:

- catálogo consultável do PDV
- carrinho
- checkout offline completo
- recibo PDF
- caixa local
- sync inbox incremental
- persistência backend via Prisma
- CRUDs completos de ERP e CRM

## Regra de evolução

Os próximos incrementos devem preservar estas fronteiras:

- checkout nunca depende do backend para concluir
- `ERP` e `CRM` não devem virar módulos offline-first por acidente
- lógica de sync não deve ser embutida em widgets
- regras de role/tenant devem continuar sendo validadas no backend
