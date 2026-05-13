from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import bcrypt
import jwt
import datetime
from api.database import get_connection

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


SECRET_KEY ="BD2_PROJETO_2026"
ALGORITHM = "HS256"

@router.post("/login")
def login(body: LoginRequest):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT UtilizadorID, PasswordHash FROM Utilizadores WHERE Email = %s",
                (body.email,)
            )
            user = cur.fetchone()

            if not user or not bcrypt.checkpw(body.password.encode(), user["passwordhash"].encode()):
                raise HTTPException(status_code=401, detail="Email ou password incorretos.")

            # O payload contém o ID do utilizador (sub) e a expiração (exp)
            payload = {
                "sub": str(user["utilizadorid"]),
                "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=8)
            }
            token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

            return {
                "access_token": token,
                "token_type": "bearer",
                "utilizador_id": user["utilizadorid"]
            }
    finally:
        conn.close()
