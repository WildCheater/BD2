# VoltExchange — Resumo do Projeto

## Contexto principal
- **Disciplina**: Base de Dados II, Eng. Informática, 2025/2026
- **Objetivo**: Backend completo para plataforma P2P de compra/venda de energia solar entre Prosumers
- **Raiz do projeto**: `c:\Users\hugom\OneDrive\UNI\Base de Dados II\Prático\projeto\voltexchange\`

## Stack
- **BD**: PostgreSQL (servidor da escola, obrigatório para entrega final)
- **API**: Python FastAPI, deploy em Vercel (`vercel.json` presente)
- **Auth**: JWT (PyJWT) + bcrypt para hashing passwords
- **Driver BD**: psycopg2 com `RealDictCursor`, prepared statements obrigatórios

## Estrutura de ficheiros
```
voltexchange/
├── ddl.sql          — 6 tabelas (Anexo A), partições, índices
├── seed.sql         — 10 users, 50 contadores, 500k leituras, 1000 ofertas
├── logic.sql        — 2 triggers, sp_ExecutarCompraDireta, sp_MatchingEngine, sp_QuarentenaUtilizador
├── vercel.json
└── api/
    ├── main.py          — FastAPI app, routers montados em /api/*
    ├── database.py      — get_connection() via env vars (DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD)
    ├── auth_utils.py    — create_token(), get_current_user() (JWT, env: JWT_SECRET)
    ├── requirements.txt — fastapi, uvicorn, psycopg2-binary, bcrypt, pydantic, PyJWT
    └── routes/
        ├── auth.py    — POST /register, /login → retornam JWT token
        ├── meters.py  — POST /readings (grava leitura + JSONB)
        ├── market.py  — POST /buy (sp_ExecutarCompraDireta), /order (OrdensCompra), /match (sp_MatchingEngine)
        └── admin.py   — GET /anomalies (contadores MANUTENCAO, query JSONB+GIN)
```

## Decisões tomadas
- Schema `voltexchange` (SET search_path)
- Tabela Leituras particionada por RANGE(DataHora), mensal 2024-01→2026-04 + catch-all
- Índice GIN em DadosAudit; B-tree em ContadorID
- Anomalia = `temperatura > 80` OR `erro_codigo` presente
- Endpoints /buy e /order usam JWT (Authorization: Bearer) — `comprador_id` extraído do token, não do body
- /match não requer auth (para o docente testar)

## Implementado ✅
- Todas as 6 tabelas do Anexo A com PKs, FKs, CHECKs, UNIQUE
- Particionamento + índice GIN + B-tree
- Seed: 500k leituras, 1000 ofertas
- Trigger 1: anomalia nas leituras → contador MANUTENCAO
- Trigger 2: impede DELETE de utilizador (saldo > 0 ou ofertas ativas)
- sp_ExecutarCompraDireta (ACID, FOR UPDATE)
- sp_MatchingEngine (loop OrdensCompra PENDENTE, match por preço + data)
- sp_QuarentenaUtilizador
- Todos os 7 endpoints obrigatórios da API
- Segurança: prepared statements + bcrypt + JWT

## Pendências ❌
1. **Trigger 2 incompleto** — verifica ofertas ativas, mas enunciado pede **transações recentes** (tabela Transacoes, ex: últimos 30 dias)
2. **sp_MatchingEngine sem critério de região** — enunciado pede: 1º Preço, 2º Proximidade (mesma região), 3º Data. Não existe campo Região no schema
3. **Trigger Event-Driven** (desafio nota máxima) — AFTER INSERT em OrdensCompra/OfertasVenda → disparar matching automaticamente
4. **Relatório Técnico (PDF)** — Diagrama ER, justificação índices/partições, planos de execução, links API produção
5. **Deploy Cloud** — vercel.json existe mas não confirmado se está deployed

## Possíveis problemas ⚠️
- `ROLLBACK` explícito dentro de bloco EXCEPTION em sp_ExecutarCompraDireta — pode causar issues em PostgreSQL (usar SAVEPOINT ou deixar sub-bloco BEGIN..EXCEPTION tratar)
- Queries da API não prefixam schema `voltexchange.` — depende do search_path estar configurado na sessão

## Restrições
- Entrega final obrigatoriamente no servidor PostgreSQL da escola
- Prepared statements obrigatórios (concatenação proibida)
- Passwords nunca em texto limpo
- ZIP final: código API (sem node_modules), ddl.sql, seed.sql, logic.sql, relatório PDF
