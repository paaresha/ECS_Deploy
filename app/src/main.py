"""
FastAPI application – the containerized service deployed to ECS/Fargate.
Exposes /health, /ready, /metrics, and a simple /api/v1/items CRUD surface.
"""

import os
import time
import logging
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

# ── logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
)
log = logging.getLogger(__name__)

# ── startup / shutdown ────────────────────────────────────────────────────────
START_TIME = time.time()
_items: dict[int, dict] = {}
_next_id = 1


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("Application starting up …")
    yield
    log.info("Application shutting down …")


# ── app ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="CI/CD Demo API",
    description="Sample API deployed via GitHub Actions → ECR → ECS/Fargate",
    version=os.getenv("APP_VERSION", "1.0.0"),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── middleware: request logging ───────────────────────────────────────────────
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration_ms = (time.time() - start) * 1000
    log.info(
        "%s %s → %s  (%.1f ms)",
        request.method,
        request.url.path,
        response.status_code,
        duration_ms,
    )
    return response


# ── schemas ───────────────────────────────────────────────────────────────────
class ItemCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    description: str = Field(default="", max_length=1000)
    price: float = Field(..., gt=0)


class Item(ItemCreate):
    id: int
    created_at: str


# ── health / readiness ────────────────────────────────────────────────────────
@app.get("/health", tags=["ops"])
async def health():
    """ECS health-check endpoint."""
    return {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "uptime_seconds": round(time.time() - START_TIME, 1),
        "version": app.version,
        "environment": os.getenv("ENVIRONMENT", "local"),
    }


@app.get("/ready", tags=["ops"])
async def ready():
    """Kubernetes/ALB readiness probe."""
    return {"ready": True}


@app.get("/metrics", tags=["ops"])
async def metrics():
    """Lightweight Prometheus-style metrics (plaintext)."""
    uptime = round(time.time() - START_TIME, 1)
    lines = [
        "# HELP app_uptime_seconds Seconds since application start",
        "# TYPE app_uptime_seconds gauge",
        f"app_uptime_seconds {uptime}",
        "# HELP app_items_total Total number of items in the store",
        "# TYPE app_items_total gauge",
        f"app_items_total {len(_items)}",
    ]
    from fastapi.responses import PlainTextResponse
    return PlainTextResponse("\n".join(lines) + "\n")


# ── items API ─────────────────────────────────────────────────────────────────
@app.get("/api/v1/items", tags=["items"])
async def list_items():
    return {"items": list(_items.values()), "total": len(_items)}


@app.post("/api/v1/items", status_code=201, tags=["items"])
async def create_item(payload: ItemCreate):
    global _next_id
    item = Item(
        id=_next_id,
        created_at=datetime.now(timezone.utc).isoformat(),
        **payload.model_dump(),
    )
    _items[_next_id] = item.model_dump()
    _next_id += 1
    log.info("Created item id=%s name=%s", item.id, item.name)
    return item


@app.get("/api/v1/items/{item_id}", tags=["items"])
async def get_item(item_id: int):
    if item_id not in _items:
        raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
    return _items[item_id]


@app.put("/api/v1/items/{item_id}", tags=["items"])
async def update_item(item_id: int, payload: ItemCreate):
    if item_id not in _items:
        raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
    existing = _items[item_id]
    updated = {**existing, **payload.model_dump()}
    _items[item_id] = updated
    return updated


@app.delete("/api/v1/items/{item_id}", status_code=204, tags=["items"])
async def delete_item(item_id: int):
    if item_id not in _items:
        raise HTTPException(status_code=404, detail=f"Item {item_id} not found")
    del _items[item_id]


# ── version info ──────────────────────────────────────────────────────────────
@app.get("/", tags=["root"])
async def root():
    return {
        "service": "ci-cd-demo-api",
        "version": app.version,
        "docs": "/docs",
        "health": "/health",
    }
