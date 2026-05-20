from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class HeatmapCellOut(BaseModel):
    x: float
    y: float
    rssi_dbm: float
    normalized: float
    color: str


class HeatmapOut(BaseModel):
    proyecto_id: int
    plano_id: int
    metric: Literal["best_rssi", "avg_rssi"]
    resolution: int
    min_rssi: int
    max_rssi: int
    generated_at: datetime
    points_used: int
    warning: str | None
    grid: list[HeatmapCellOut]
