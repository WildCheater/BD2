import os
import jwt
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException, Header

# Chave secreta para assinar os tokens — definir como variável de ambiente em produção
SECRET_KEY = os.environ.get("JWT_SECRET", "voltexchange_secret_key_change_in_prod")
ALGORITHM = "HS256"
TOKEN_EXPIRY_HOURS = 24


def create_token(utilizador_id: int) -> str:
    """Gera um JWT com o UtilizadorID e expiração."""
    payload = {
        "utilizador_id": utilizador_id,
        "exp": datetime.now(timezone.utc) + timedelta(hours=TOKEN_EXPIRY_HOURS),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(authorization: str = Header(...)) -> int:
    """
    Dependência FastAPI — extrai o UtilizadorID do token JWT.
    Espera header: Authorization: Bearer <token>
    """
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Formato de token inválido. Use: Bearer <token>")

    token = authorization.split(" ", 1)[1]

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload["utilizador_id"]
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expirado.")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Token inválido.")
