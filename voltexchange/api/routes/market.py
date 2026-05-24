from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from api.database import get_connection
from api.auth_utils import get_current_user

router = APIRouter()

class BuyRequest(BaseModel):
    oferta_id: int

class OrderRequest(BaseModel):
    quantidade_kwh: float
    preco_maximo: float


@router.post("/buy")
def compra_direta(body: BuyRequest, utilizador_id: int = Depends(get_current_user)):
    """Compra imediata — chama sp_ExecutarCompraDireta (ACID)"""
    conn = get_connection()
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            # Prepared Statement — parâmetros passados separadamente
            cur.execute(
                "CALL sp_ExecutarCompraDireta(%s, %s)",
                (body.oferta_id, utilizador_id)
            )
            conn.commit()
            return {"message": "Compra realizada com sucesso."}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()


@router.post("/order")
def criar_ordem(body: OrderRequest, utilizador_id: int = Depends(get_current_user)):
    """Cria uma intenção de compra futura em OrdensCompra"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # Prepared Statement
            cur.execute(
                """
                INSERT INTO OrdensCompra (CompradorID, QuantidadeKWh, PrecoMaximo, Estado, DataCriacao)
                VALUES (%s, %s, %s, 'PENDENTE', NOW())
                RETURNING OrdemID
                """,
                (utilizador_id, body.quantidade_kwh, body.preco_maximo)
            )
            ordem_id = cur.fetchone()["ordemid"]
            conn.commit()
            return {"message": "Ordem de compra criada.", "ordem_id": ordem_id}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()


@router.post("/match")
def executar_matching():
    """Dispara manualmente o sp_MatchingEngine — obrigatório para testes do docente"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("CALL sp_MatchingEngine()")
            conn.commit()
            return {"message": "Matching Engine executado com sucesso."}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

