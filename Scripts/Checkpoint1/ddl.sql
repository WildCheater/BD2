-- ============================================================
--  VoltExchange — DDL
--  Checkpoint 1 | BD II 2025/2026
--  Executa este script no servidor PostgreSQL da escola.
-- ============================================================

-- ------------------------------------------------------------
-- 0. Limpeza (ordem inversa de dependências)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS Transacoes       CASCADE;
DROP TABLE IF EXISTS OrdensCompra     CASCADE;
DROP TABLE IF EXISTS OfertasVenda     CASCADE;
DROP TABLE IF EXISTS Leituras         CASCADE;
DROP TABLE IF EXISTS Contadores       CASCADE;
DROP TABLE IF EXISTS Utilizadores     CASCADE;

-- ------------------------------------------------------------
-- 1. Utilizadores
-- ------------------------------------------------------------
CREATE TABLE Utilizadores (
    UtilizadorID  SERIAL          PRIMARY KEY,
    Nome          VARCHAR(150)    NOT NULL,
    Email         VARCHAR(255)    NOT NULL UNIQUE,
    PasswordHash  VARCHAR(255)    NOT NULL,   -- bcrypt / Argon2, nunca texto limpo
    Saldo         NUMERIC(12, 4)  NOT NULL DEFAULT 0.00
);

-- ------------------------------------------------------------
-- 2. Contadores
-- ------------------------------------------------------------
CREATE TABLE Contadores (
    ContadorID    SERIAL          PRIMARY KEY,
    UtilizadorID  INT             NOT NULL REFERENCES Utilizadores(UtilizadorID),
    NumeroSerie   VARCHAR(100)    NOT NULL UNIQUE,
    Estado        VARCHAR(20)     NOT NULL DEFAULT 'ATIVO'
                                  CHECK (Estado IN ('ATIVO', 'MANUTENCAO'))
);

CREATE INDEX idx_contadores_utilizador ON Contadores(UtilizadorID);

-- ------------------------------------------------------------
-- 3. Leituras  (particionada por DATA — RANGE mensal)
--    A chave primária inclui DataHora para satisfazer o
--    requisito do PostgreSQL sobre partições e PKs.
-- ------------------------------------------------------------
CREATE TABLE Leituras (
    LeituraID     BIGSERIAL,
    ContadorID    INT             NOT NULL,   -- FK gerida a nível de aplicação/trigger
    DataHora      TIMESTAMP       NOT NULL,
    KWh_Leitura   NUMERIC(10, 4)  NOT NULL,
    DadosAudit    JSONB,                      -- logs técnicos: temperatura, erros, etc.
    PRIMARY KEY (LeituraID, DataHora)
) PARTITION BY RANGE (DataHora);

-- Partições mensais para 2024 e 2025 (ajusta conforme necessário)
CREATE TABLE Leituras_2024_01 PARTITION OF Leituras
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE Leituras_2024_02 PARTITION OF Leituras
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE Leituras_2024_03 PARTITION OF Leituras
    FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');
CREATE TABLE Leituras_2024_04 PARTITION OF Leituras
    FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');
CREATE TABLE Leituras_2024_05 PARTITION OF Leituras
    FOR VALUES FROM ('2024-05-01') TO ('2024-06-01');
CREATE TABLE Leituras_2024_06 PARTITION OF Leituras
    FOR VALUES FROM ('2024-06-01') TO ('2024-07-01');
CREATE TABLE Leituras_2024_07 PARTITION OF Leituras
    FOR VALUES FROM ('2024-07-01') TO ('2024-08-01');
CREATE TABLE Leituras_2024_08 PARTITION OF Leituras
    FOR VALUES FROM ('2024-08-01') TO ('2024-09-01');
CREATE TABLE Leituras_2024_09 PARTITION OF Leituras
    FOR VALUES FROM ('2024-09-01') TO ('2024-10-01');
CREATE TABLE Leituras_2024_10 PARTITION OF Leituras
    FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');
CREATE TABLE Leituras_2024_11 PARTITION OF Leituras
    FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');
CREATE TABLE Leituras_2024_12 PARTITION OF Leituras
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

CREATE TABLE Leituras_2025_01 PARTITION OF Leituras
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE Leituras_2025_02 PARTITION OF Leituras
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE Leituras_2025_03 PARTITION OF Leituras
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE Leituras_2025_04 PARTITION OF Leituras
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE Leituras_2025_05 PARTITION OF Leituras
    FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE Leituras_2025_06 PARTITION OF Leituras
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE Leituras_2025_07 PARTITION OF Leituras
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE Leituras_2025_08 PARTITION OF Leituras
    FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE Leituras_2025_09 PARTITION OF Leituras
    FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE Leituras_2025_10 PARTITION OF Leituras
    FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE Leituras_2025_11 PARTITION OF Leituras
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE Leituras_2025_12 PARTITION OF Leituras
    FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

CREATE TABLE Leituras_2026_01 PARTITION OF Leituras
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE Leituras_2026_02 PARTITION OF Leituras
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE Leituras_2026_03 PARTITION OF Leituras
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE Leituras_2026_04 PARTITION OF Leituras
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

-- Partição "catch-all" para datas futuras não cobertas acima
CREATE TABLE Leituras_futuras PARTITION OF Leituras
    FOR VALUES FROM ('2026-05-01') TO ('2100-01-01');

-- Índice GIN no campo JSONB (pesquisas de anomalias)
CREATE INDEX idx_leituras_dadosaudit_gin
    ON Leituras USING GIN (DadosAudit);

-- Índice B-tree no ContadorID para JOINs rápidos
CREATE INDEX idx_leituras_contador
    ON Leituras (ContadorID);

-- ------------------------------------------------------------
-- 4. OfertasVenda
-- ------------------------------------------------------------
CREATE TABLE OfertasVenda (
    OfertaID        SERIAL          PRIMARY KEY,
    VendedorID      INT             NOT NULL REFERENCES Utilizadores(UtilizadorID),
    QuantidadeKWh   NUMERIC(10, 4)  NOT NULL CHECK (QuantidadeKWh > 0),
    PrecoUnitario   NUMERIC(10, 4)  NOT NULL CHECK (PrecoUnitario > 0),
    Estado          VARCHAR(20)     NOT NULL DEFAULT 'ATIVA'
                                    CHECK (Estado IN ('ATIVA', 'VENDIDA', 'CANCELADA')),
    DataCriacao     TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ofertas_estado       ON OfertasVenda(Estado);
CREATE INDEX idx_ofertas_vendedor     ON OfertasVenda(VendedorID);
CREATE INDEX idx_ofertas_preco        ON OfertasVenda(PrecoUnitario) WHERE Estado = 'ATIVA';

-- ------------------------------------------------------------
-- 5. OrdensCompra  (usada pelo Matching Engine)
-- ------------------------------------------------------------
CREATE TABLE OrdensCompra (
    OrdemID         SERIAL          PRIMARY KEY,
    CompradorID     INT             NOT NULL REFERENCES Utilizadores(UtilizadorID),
    QuantidadeKWh   NUMERIC(10, 4)  NOT NULL CHECK (QuantidadeKWh > 0),
    PrecoMaximo     NUMERIC(10, 4)  NOT NULL CHECK (PrecoMaximo > 0),
    Estado          VARCHAR(20)     NOT NULL DEFAULT 'PENDENTE'
                                    CHECK (Estado IN ('PENDENTE', 'CONCLUIDA')),
    DataCriacao     TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ordens_estado    ON OrdensCompra(Estado);
CREATE INDEX idx_ordens_comprador ON OrdensCompra(CompradorID);

-- ------------------------------------------------------------
-- 6. Transacoes
-- ------------------------------------------------------------
CREATE TABLE Transacoes (
    TransacaoID     SERIAL          PRIMARY KEY,
    OfertaID        INT             REFERENCES OfertasVenda(OfertaID),   -- nullable
    CompradorID     INT             NOT NULL REFERENCES Utilizadores(UtilizadorID),
    VendedorID      INT             NOT NULL REFERENCES Utilizadores(UtilizadorID),
    ValorTotal      NUMERIC(12, 4)  NOT NULL CHECK (ValorTotal > 0),
    DataTransacao   TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transacoes_comprador ON Transacoes(CompradorID);
CREATE INDEX idx_transacoes_vendedor  ON Transacoes(VendedorID);
CREATE INDEX idx_transacoes_data      ON Transacoes(DataTransacao);

-- ============================================================
--  FIM DO DDL
-- ============================================================
