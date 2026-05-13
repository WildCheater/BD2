from fastapi import APIRouter, HTTPException, Header, Depends
from pydantic import BaseModel
from api.database import get_connection

router = APIRouter()

class BuyRequest(BaseModel):
    oferta_id: int
    comprador_id: int

class OrderRequest(BaseModel):
    comprador_id: int
    quantidade_kwh: float
    preco_maximo: float

def get_current_user(authorization: str = Header(None)):
    if not authorization:
        raise HTTPException(status_code=401, detail="Token ausente.")
    try:
        token = authorization.split(" ")[1] # Remove "Bearer "
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return int(payload["sub"])
    except Exception:
        raise HTTPException(status_code=401, detail="Token inválido ou expirado.")

@router.post("/buy")
def compra_direta(body: BuyRequest, user_id: int = Depends(get_current_user)):
    """O comprador_id agora vem do token (user_id)"""
    conn = get_connection()
    conn.autocommit = True 
    try:
        with conn.cursor() as cur:
            # Usamos o user_id extraído do token por segurança
            cur.execute(
                "CALL sp_ExecutarCompraDireta(%s, %s)",
                (body.oferta_id, user_id)
            )
            return {"message": "Compra realizada com sucesso."}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

@router.post("/order")
def criar_ordem(body: OrderRequest):
    """Cria uma intenção de compra futura — INSERT simples (sem COMMIT interno na DB)"""
    conn = get_connection()
    # Aqui mantemos o comportamento padrão (autocommit=False) para garantir o commit manual do Python
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO OrdensCompra (CompradorID, QuantidadeKWh, PrecoMaximo, Estado, DataCriacao)
                VALUES (%s, %s, %s, 'PENDENTE', NOW())
                RETURNING OrdemID
                """,
                (body.comprador_id, body.quantidade_kwh, body.preco_maximo)
            )
            # Acede ao resultado (garante que os nomes das colunas batem com o teu esquema adaptado)
            result = cur.fetchone()
            ordem_id = result["ordemid"] if isinstance(result, dict) else result[0]
            conn.commit()
            return {"message": "Ordem de compra criada.", "ordem_id": ordem_id}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

@router.post("/match")
def executar_matching():
    """Dispara o sp_MatchingEngine — Necessário autocommit se houver COMMITs na procedure"""
    conn = get_connection()
    conn.autocommit = True 
    try:
        with conn.cursor() as cur:
            cur.execute("CALL sp_MatchingEngine()")
            return {"message": "Matching Engine executado com sucesso."}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()