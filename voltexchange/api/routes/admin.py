from fastapi import APIRouter, HTTPException
from api.database import get_connection

router = APIRouter()

@router.get("/anomalies")
def listar_anomalias():
    """
    Lista contadores em MANUTENCAO com a leitura anómala que causou o problema.
    Usa o índice GIN no campo DadosAudit (JSONB) para performance.
    """
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    c.ContadorID,
                    c.NumeroSerie,
                    c.Estado,
                    u.Nome        AS Utilizador,
                    u.Email,
                    l.LeituraID,
                    l.DataHora,
                    l.DadosAudit
                FROM Contadores c
                JOIN Utilizadores u ON u.UtilizadorID = c.UtilizadorID
                JOIN Leituras l     ON l.ContadorID   = c.ContadorID
                WHERE c.Estado = 'MANUTENCAO'
                  AND (
                      -- Anomalia tipo 1: temperatura > 80 (usa índice GIN)
                      (l.DadosAudit->>'temperatura')::NUMERIC > 80
                      OR
                      -- Anomalia tipo 2: erro_codigo presente (usa índice GIN)
                      l.DadosAudit ? 'erro_codigo'
                  )
                ORDER BY l.DataHora DESC
                """
            )
            rows = cur.fetchall()
            return {"total": len(rows), "anomalias": rows}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
