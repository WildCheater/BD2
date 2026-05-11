from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import bcrypt
from database import get_connection

router = APIRouter()

class RegisterRequest(BaseModel):
    nome: str
    email: str
    password: str

class LoginRequest(BaseModel):
    email: str
    password: str


@router.post("/register")
def register(body: RegisterRequest):
    # Hash da password com bcrypt
    password_hash = bcrypt.hashpw(body.password.encode(), bcrypt.gensalt()).decode()

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # Prepared Statement — evita SQL Injection
            cur.execute(
                "INSERT INTO Utilizadores (Nome, Email, PasswordHash, Saldo) VALUES (%s, %s, %s, 0) RETURNING UtilizadorID",
                (body.nome, body.email, password_hash)
            )
            user_id = cur.fetchone()["utilizadorid"]
            conn.commit()
            return {"message": "Utilizador criado com sucesso.", "utilizador_id": user_id}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()


@router.post("/login")
def login(body: LoginRequest):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # Prepared Statement — evita SQL Injection
            cur.execute(
                "SELECT UtilizadorID, PasswordHash FROM Utilizadores WHERE Email = %s",
                (body.email,)
            )
            user = cur.fetchone()

            if not user:
                raise HTTPException(status_code=401, detail="Email ou password incorretos.")

            # Verificar password com bcrypt
            if not bcrypt.checkpw(body.password.encode(), user["passwordhash"].encode()):
                raise HTTPException(status_code=401, detail="Email ou password incorretos.")

            return {"message": "Login bem-sucedido.", "utilizador_id": user["utilizadorid"]}
    finally:
        conn.close()
