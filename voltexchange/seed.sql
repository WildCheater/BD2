-- ============================================================
--  VoltExchange — SEED
--  Checkpoint 1 | BD II 2025/2026
--
--  Gera:
--    • 10  Utilizadores
--    • 50  Contadores  (5 por utilizador)
--    • 500 000 Leituras distribuídas por 2024-2025
--    • 1 000 OfertasVenda
-- ============================================================

SET search_path TO voltexchange;

BEGIN;

-- ------------------------------------------------------------
-- 1. Utilizadores  (passwords são hashes bcrypt fictícios para seed)
-- ------------------------------------------------------------
INSERT INTO
    Utilizadores (
        Nome,
        Email,
        PasswordHash,
        Saldo
    )
VALUES (
        'Alice Ferreira',
        'alice@voltex.pt',
        '$2b$12$AAAAAAAAAAAAAAAAAAAAAA.seed_hash_alice',
        1500.00
    ),
    (
        'Bruno Costa',
        'bruno@voltex.pt',
        '$2b$12$BBBBBBBBBBBBBBBBBBBBBB.seed_hash_bruno',
        800.50
    ),
    (
        'Carla Mendes',
        'carla@voltex.pt',
        '$2b$12$CCCCCCCCCCCCCCCCCCCCCC.seed_hash_carla',
        2200.75
    ),
    (
        'David Sousa',
        'david@voltex.pt',
        '$2b$12$DDDDDDDDDDDDDDDDDDDDDD.seed_hash_david',
        350.00
    ),
    (
        'Eva Rodrigues',
        'eva@voltex.pt',
        '$2b$12$EEEEEEEEEEEEEEEEEEEEEE.seed_hash_eva',
        5000.00
    ),
    (
        'Filipe Neves',
        'filipe@voltex.pt',
        '$2b$12$FFFFFFFFFFFFFFFFFFFFFF.seed_hash_filipe',
        120.25
    ),
    (
        'Graça Lima',
        'graca@voltex.pt',
        '$2b$12$GGGGGGGGGGGGGGGGGGGGGG.seed_hash_graca',
        3300.00
    ),
    (
        'Hugo Pinto',
        'hugo@voltex.pt',
        '$2b$12$HHHHHHHHHHHHHHHHHHHHHH.seed_hash_hugo',
        675.80
    ),
    (
        'Inês Carvalho',
        'ines@voltex.pt',
        '$2b$12$IIIIIIIIIIIIIIIIIIIIII.seed_hash_ines',
        1100.00
    ),
    (
        'João Oliveira',
        'joao@voltex.pt',
        '$2b$12$JJJJJJJJJJJJJJJJJJJJJJ.seed_hash_joao',
        9999.99
    );

-- ------------------------------------------------------------
-- 2. Contadores  (5 por utilizador = 50 no total)
-- ------------------------------------------------------------
INSERT INTO Contadores (UtilizadorID, NumeroSerie, Estado)
SELECT
    u.UtilizadorID,
    'SN-' || LPAD(u.UtilizadorID::TEXT, 3, '0') || '-' || LPAD(s::TEXT, 2, '0'),
    'ATIVO'
FROM Utilizadores u,
     generate_series(1, 5) AS s;

-- ------------------------------------------------------------
-- 3. Leituras  — 500 000 registos
--
--  Distribuição: uma leitura a cada ~1 hora entre
--  2024-01-01 e o limite que gerar_series cobrir.
--  DadosAudit alterna entre:
--    • normal           → {"temperatura": X, "tensao": Y}
--    • anomalia tipo 1  → {"temperatura": 85, "tensao": Y}   (temp > 80)
--    • anomalia tipo 2  → {"erro_codigo": "E42", "tensao": Y} (erro presente)
--    • ~5 % de cada anomalia, o resto normal
-- ------------------------------------------------------------
INSERT INTO Leituras (ContadorID, DataHora, KWh_Leitura, DadosAudit)
SELECT
    -- ContadorID: busca os IDs reais da tabela, ciclando pelos existentes
    (SELECT ContadorID FROM Contadores
     ORDER BY ContadorID
     OFFSET mod(seq - 1, (SELECT COUNT(*) FROM Contadores)::INT)
     LIMIT 1)                                           AS ContadorID,

-- DataHora: distribuída aleatoriamente entre 2024-01-01 e 2026-04-30
TIMESTAMP '2024-01-01 00:00:00'
        + (random() * 86400 * 850)::INT * INTERVAL '1 second' AS DataHora,

-- Consumo / produção aleatório entre 0.1 e 15 kWh
ROUND((random() * 14.9 + 0.1)::NUMERIC, 4) AS KWh_Leitura,

-- DadosAudit: ~5 % anomalia temperatura, ~5 % anomalia erro_codigo, resto normal


CASE
        WHEN mod(seq, 20) = 0 THEN
            jsonb_build_object(
                'temperatura', (81 + (random() * 19)::INT),   -- > 80  → anomalia
                'tensao',      ROUND((220 + random() * 10)::NUMERIC, 1),
                'fonte',       'sensor_v2'
            )
        WHEN mod(seq, 20) = 1 THEN
            jsonb_build_object(
                'erro_codigo', 'E' || (10 + (random() * 90)::INT)::TEXT,
                'tensao',      ROUND((220 + random() * 10)::NUMERIC, 1),
                'fonte',       'sensor_v2'
            )
        ELSE
            jsonb_build_object(
                'temperatura', ROUND((20 + random() * 55)::NUMERIC, 1),  -- 20..75 → normal
                'tensao',      ROUND((220 + random() * 10)::NUMERIC, 1),
                'fonte',       'sensor_v2'
            )
    END                                                  AS DadosAudit

FROM generate_series(1, 500000) AS seq;

-- ------------------------------------------------------------
-- 4. OfertasVenda  — 1 000 registos
-- ------------------------------------------------------------


INSERT INTO OfertasVenda (VendedorID, QuantidadeKWh, PrecoUnitario, Estado, DataCriacao)
SELECT
    -- VendedorID: cicla pelos 10 utilizadores
    (mod(seq - 1, 10) + 1)::INT                          AS VendedorID,

    ROUND((random() * 49.5 + 0.5)::NUMERIC, 4)          AS QuantidadeKWh,
    ROUND((random() * 0.19 + 0.05)::NUMERIC, 4)         AS PrecoUnitario,  -- €0.05 – €0.24

    CASE
        WHEN mod(seq, 20) < 16 THEN 'ATIVA'       -- 80 %
        WHEN mod(seq, 20) < 19 THEN 'VENDIDA'     -- 15 %
        ELSE                        'CANCELADA'   --  5 %
    END                                                  AS Estado,

    NOW() - ((random() * 365)::INT * INTERVAL '1 day')  AS DataCriacao

FROM generate_series(1, 1000) AS seq;

COMMIT;

-- ------------------------------------------------------------
-- Verificação rápida
-- ------------------------------------------------------------
SELECT 'Utilizadores' AS tabela, COUNT(*) AS total
FROM Utilizadores
UNION ALL
SELECT 'Contadores', COUNT(*)
FROM Contadores
UNION ALL
SELECT 'Leituras', COUNT(*)
FROM Leituras
UNION ALL
SELECT 'OfertasVenda', COUNT(*)
FROM OfertasVenda;