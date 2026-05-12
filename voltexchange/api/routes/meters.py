from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Any, Dict
import json
from api.database import get_connection

router = APIRouter()

class ReadingRequest(BaseModel):
    contador_id: int
    kwh_leitura: float
    dados_audit: Dict[str, Any]  # JSON livre: temperatura, erros, etc.


@router.post("/readings")
def create_reading(body: ReadingRequest):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # Prepared Statement — dados_audit guardado como JSONB
            cur.execute(
                """
                INSERT INTO Leituras (ContadorID, DataHora, KWh_Leitura, DadosAudit)
                VALUES (%s, NOW(), %s, %s)
                RETURNING LeituraID
                """,
                (body.contador_id, body.kwh_leitura, json.dumps(body.dados_audit))
            )
            leitura_id = cur.fetchone()["leituraid"]
            conn.commit()
            return {"message": "Leitura registada.", "leitura_id": leitura_id}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()
