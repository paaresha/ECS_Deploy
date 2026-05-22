"""
Comprehensive test suite for the FastAPI application.
Tests health endpoints, CRUD operations, error handling, and edge cases.
"""

import pytest
from httpx import AsyncClient, ASGITransport

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from main import app, _items, _next_id


# ── fixtures ──────────────────────────────────────────────────────────────────
@pytest.fixture(autouse=True)
def reset_store():
    """Clear in-memory store before every test."""
    global _next_id
    _items.clear()
    import main as m
    m._next_id = 1
    yield
    _items.clear()
    m._next_id = 1


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


# ── health / ops ──────────────────────────────────────────────────────────────
class TestHealthEndpoints:
    @pytest.mark.asyncio
    async def test_health_returns_200(self, client):
        resp = await client.get("/health")
        assert resp.status_code == 200

    @pytest.mark.asyncio
    async def test_health_payload(self, client):
        resp = await client.get("/health")
        data = resp.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data
        assert "uptime_seconds" in data
        assert "version" in data
        assert "environment" in data

    @pytest.mark.asyncio
    async def test_ready_returns_200(self, client):
        resp = await client.get("/ready")
        assert resp.status_code == 200
        assert resp.json()["ready"] is True

    @pytest.mark.asyncio
    async def test_metrics_endpoint(self, client):
        resp = await client.get("/metrics")
        assert resp.status_code == 200
        assert "app_uptime_seconds" in resp.text
        assert "app_items_total" in resp.text

    @pytest.mark.asyncio
    async def test_root_endpoint(self, client):
        resp = await client.get("/")
        assert resp.status_code == 200
        data = resp.json()
        assert "service" in data
        assert "version" in data


# ── items CRUD ────────────────────────────────────────────────────────────────
class TestItemsCRUD:
    VALID_ITEM = {"name": "Widget A", "description": "A quality widget", "price": 19.99}

    @pytest.mark.asyncio
    async def test_list_items_empty(self, client):
        resp = await client.get("/api/v1/items")
        assert resp.status_code == 200
        data = resp.json()
        assert data["items"] == []
        assert data["total"] == 0

    @pytest.mark.asyncio
    async def test_create_item(self, client):
        resp = await client.post("/api/v1/items", json=self.VALID_ITEM)
        assert resp.status_code == 201
        data = resp.json()
        assert data["id"] == 1
        assert data["name"] == "Widget A"
        assert data["price"] == 19.99
        assert "created_at" in data

    @pytest.mark.asyncio
    async def test_create_multiple_items(self, client):
        for i in range(3):
            resp = await client.post(
                "/api/v1/items",
                json={"name": f"Item {i}", "price": float(i + 1)},
            )
            assert resp.status_code == 201

        resp = await client.get("/api/v1/items")
        assert resp.json()["total"] == 3

    @pytest.mark.asyncio
    async def test_get_item_by_id(self, client):
        await client.post("/api/v1/items", json=self.VALID_ITEM)
        resp = await client.get("/api/v1/items/1")
        assert resp.status_code == 200
        assert resp.json()["name"] == "Widget A"

    @pytest.mark.asyncio
    async def test_get_nonexistent_item(self, client):
        resp = await client.get("/api/v1/items/999")
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_update_item(self, client):
        await client.post("/api/v1/items", json=self.VALID_ITEM)
        resp = await client.put(
            "/api/v1/items/1",
            json={"name": "Updated Widget", "description": "Updated desc", "price": 29.99},
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "Updated Widget"
        assert resp.json()["price"] == 29.99

    @pytest.mark.asyncio
    async def test_update_nonexistent_item(self, client):
        resp = await client.put(
            "/api/v1/items/999",
            json={"name": "X", "price": 1.0},
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_item(self, client):
        await client.post("/api/v1/items", json=self.VALID_ITEM)
        resp = await client.delete("/api/v1/items/1")
        assert resp.status_code == 204

        resp = await client.get("/api/v1/items/1")
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_nonexistent_item(self, client):
        resp = await client.delete("/api/v1/items/999")
        assert resp.status_code == 404


# ── validation ────────────────────────────────────────────────────────────────
class TestValidation:
    @pytest.mark.asyncio
    async def test_create_item_missing_name(self, client):
        resp = await client.post("/api/v1/items", json={"price": 10.0})
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_create_item_negative_price(self, client):
        resp = await client.post("/api/v1/items", json={"name": "X", "price": -1.0})
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_create_item_zero_price(self, client):
        resp = await client.post("/api/v1/items", json={"name": "X", "price": 0})
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_create_item_empty_name(self, client):
        resp = await client.post("/api/v1/items", json={"name": "", "price": 5.0})
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_create_item_name_too_long(self, client):
        resp = await client.post(
            "/api/v1/items", json={"name": "x" * 201, "price": 5.0}
        )
        assert resp.status_code == 422


# ── metrics reflect state ─────────────────────────────────────────────────────
class TestMetricsAccuracy:
    @pytest.mark.asyncio
    async def test_metrics_item_count(self, client):
        for i in range(5):
            await client.post("/api/v1/items", json={"name": f"Item{i}", "price": 1.0})
        resp = await client.get("/metrics")
        assert "app_items_total 5" in resp.text
