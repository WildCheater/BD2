-- ------------------------------------------------------------
-- TRIGGER 1: Anomalias nas Leituras
--   Se temperatura > 80 OU erro_codigo presente → MANUTENCAO
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_verificar_anomalia()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.DadosAudit->>'temperatura') IS NOT NULL
       AND (NEW.DadosAudit->>'temperatura')::NUMERIC > 80
    THEN
        UPDATE Contadores
        SET Estado = 'MANUTENCAO'
        WHERE ContadorID = NEW.ContadorID;

    ELSIF (NEW.DadosAudit->>'erro_codigo') IS NOT NULL THEN
        UPDATE Contadores
        SET Estado = 'MANUTENCAO'
        WHERE ContadorID = NEW.ContadorID;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_verificar_anomalia
    AFTER INSERT ON Leituras
    FOR EACH ROW
    EXECUTE FUNCTION fn_verificar_anomalia();


-- ------------------------------------------------------------
-- TRIGGER 2: Proteção de Utilizadores
--   Impede DELETE se saldo > 0 ou ofertas ATIVAS
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_proteger_utilizador()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.Saldo > 0 THEN
        RAISE EXCEPTION 'Não é possível eliminar o utilizador % pois tem saldo positivo de %.',
            OLD.UtilizadorID, OLD.Saldo;
    END IF;

    IF EXISTS (
        SELECT 1 FROM OfertasVenda
        WHERE VendedorID = OLD.UtilizadorID
          AND Estado = 'ATIVA'
    ) THEN
        RAISE EXCEPTION 'Não é possível eliminar o utilizador % pois tem ofertas de venda ativas.',
            OLD.UtilizadorID;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_proteger_utilizador
    BEFORE DELETE ON Utilizadores
    FOR EACH ROW
    EXECUTE FUNCTION fn_proteger_utilizador();


-- ------------------------------------------------------------
-- STORED PROCEDURE: sp_ExecutarCompraDireta
--   Compra imediata de uma oferta — garante ACID
-- ------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_ExecutarCompraDireta(
    p_OfertaID    INT,
    p_CompradorID INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_Oferta      OfertasVenda%ROWTYPE;
    v_ValorTotal  NUMERIC;
BEGIN
	BEGIN
	
	    -- 1. Bloquear o registo para evitar race conditions
	    SELECT * INTO v_Oferta
	    FROM OfertasVenda
	    WHERE OfertaID = p_OfertaID
	    FOR UPDATE;
	
	    -- 2. Verificar se a oferta existe
	    IF NOT FOUND THEN
	        RAISE EXCEPTION 'Oferta % não encontrada.', p_OfertaID;
	    END IF;
	
	    -- 3. Verificar se ainda está ATIVA
	    IF v_Oferta.Estado <> 'ATIVA' THEN
	        RAISE EXCEPTION 'Oferta % já não está ativa. Estado atual: %.',
	            p_OfertaID, v_Oferta.Estado;
	    END IF;
	
	    -- 4. Calcular valor total
	    v_ValorTotal := v_Oferta.QuantidadeKWh * v_Oferta.PrecoUnitario;
	
	    -- 5. Verificar saldo do comprador
	    IF (SELECT Saldo FROM Utilizadores WHERE UtilizadorID = p_CompradorID) < v_ValorTotal THEN
	        RAISE EXCEPTION 'Saldo insuficiente. Valor necessário: %.', v_ValorTotal;
	    END IF;
	
	    -- 6. Debitar comprador
	    UPDATE Utilizadores
	    SET Saldo = Saldo - v_ValorTotal
	    WHERE UtilizadorID = p_CompradorID;
	
	    -- 7. Creditar vendedor
	    UPDATE Utilizadores
	    SET Saldo = Saldo + v_ValorTotal
	    WHERE UtilizadorID = v_Oferta.VendedorID;
	
	    -- 8. Marcar oferta como VENDIDA
	    UPDATE OfertasVenda
	    SET Estado = 'VENDIDA'
	    WHERE OfertaID = p_OfertaID;
	
	    -- 9. Registar transação
	    INSERT INTO Transacoes (OfertaID, CompradorID, VendedorID, ValorTotal, DataTransacao)
	    VALUES (p_OfertaID, p_CompradorID, v_Oferta.VendedorID, v_ValorTotal, NOW());

	EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			RAISE;
	END;
	COMMIT;
END;
$$;


-- ------------------------------------------------------------
-- STORED PROCEDURE: sp_MatchingEngine
--   Cruza OrdensCompra com OfertasVenda
--   Critérios: 1º Preço, 2º Data mais antiga
-- ------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_MatchingEngine()
LANGUAGE plpgsql AS $$
DECLARE
    v_Ordem      OrdensCompra%ROWTYPE;
    v_Oferta     OfertasVenda%ROWTYPE;
    v_ValorTotal NUMERIC;
BEGIN
    FOR v_Ordem IN
        SELECT * FROM OrdensCompra
        WHERE Estado = 'PENDENTE'
        ORDER BY DataCriacao ASC
    LOOP
        SELECT * INTO v_Oferta
        FROM OfertasVenda
        WHERE Estado = 'ATIVA'
          AND PrecoUnitario <= v_Ordem.PrecoMaximo
          AND QuantidadeKWh >= v_Ordem.QuantidadeKWh
        ORDER BY PrecoUnitario ASC, DataCriacao ASC
        LIMIT 1
        FOR UPDATE SKIP LOCKED;

        IF FOUND THEN
            v_ValorTotal := v_Ordem.QuantidadeKWh * v_Oferta.PrecoUnitario;

            IF (SELECT Saldo FROM Utilizadores WHERE UtilizadorID = v_Ordem.CompradorID) >= v_ValorTotal THEN

                UPDATE Utilizadores SET Saldo = Saldo - v_ValorTotal WHERE UtilizadorID = v_Ordem.CompradorID;
                UPDATE Utilizadores SET Saldo = Saldo + v_ValorTotal WHERE UtilizadorID = v_Oferta.VendedorID;
                UPDATE OfertasVenda SET Estado = 'VENDIDA'   WHERE OfertaID = v_Oferta.OfertaID;
                UPDATE OrdensCompra SET Estado = 'CONCLUIDA' WHERE OrdemID  = v_Ordem.OrdemID;

                INSERT INTO Transacoes (OfertaID, CompradorID, VendedorID, ValorTotal, DataTransacao)
                VALUES (v_Oferta.OfertaID, v_Ordem.CompradorID, v_Oferta.VendedorID, v_ValorTotal, NOW());

            END IF;
        END IF;
    END LOOP;
END;
$$;


-- ------------------------------------------------------------
-- STORED PROCEDURE: sp_QuarentenaUtilizador
-- ------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_QuarentenaUtilizador(p_UtilizadorID INT)
LANGUAGE plpgsql AS $$
BEGIN
    -- O PostgreSQL inicia uma transação implicitamente ao chamar o PROCEDURE

    -- Passo 1: Verificação
    IF NOT EXISTS (SELECT 1 FROM Utilizadores WHERE UtilizadorID = p_UtilizadorID) THEN
        RAISE EXCEPTION 'Utilizador % não encontrado.', p_UtilizadorID;
    END IF;

    -- Passo 2: Atualização dos Contadores
    UPDATE contadores
    SET Estado = 'MANUTENCAO'
    WHERE UtilizadorID = p_UtilizadorID; -- Corrigido para UtilizadorID

    -- Passo 3: Cancelar Ofertas
    UPDATE OfertasVenda
    SET Estado = 'CANCELADA'
    WHERE VendedorID = p_UtilizadorID
      AND Estado = 'ATIVA';

    -- Se chegar aqui sem erros, o COMMIT é feito automaticamente no fim do procedimento.
    -- Se qualquer UPDATE falhar, tudo sofre ROLLBACK.

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Erro ao colocar utilizador em quarentena. Revertendo alterações...';
        RAISE; 
END;
$$;
