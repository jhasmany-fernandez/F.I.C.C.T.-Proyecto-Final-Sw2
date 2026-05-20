from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class PuntoMedicionIn(BaseModel):
    plano_id: int
    x: float = Field(..., ge=0, le=1)
    y: float = Field(..., ge=0, le=1)
    modo: Literal["manual", "continuo"]
    etiqueta: str | None = Field(default=None, max_length=120)
    descripcion: str | None = Field(default=None, max_length=255)


class PuntoMedicionOut(BaseModel):
    id: int
    proyecto_id: int
    plano_id: int
    x: float
    y: float
    modo: Literal["manual", "continuo"]
    etiqueta: str | None
    descripcion: str | None
    created_at: datetime
    updated_at: datetime | None

    model_config = {"from_attributes": True}
