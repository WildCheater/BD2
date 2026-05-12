from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routes import auth, meters, market, admin

app = FastAPI(title="VoltExchange API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,   prefix="/api/auth",   tags=["Auth"])
app.include_router(meters.router, prefix="/api/meters", tags=["Meters"])
app.include_router(market.router, prefix="/api/market", tags=["Market"])
app.include_router(admin.router,  prefix="/api/admin",  tags=["Admin"])

@app.get("/")
def root():
    return {"message": "VoltExchange API online"}
