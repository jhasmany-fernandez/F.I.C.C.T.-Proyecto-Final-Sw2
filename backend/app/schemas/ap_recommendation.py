from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class APRecommendationIn(BaseModel):
    plano_id: int
    target_rssi_dbm: int = Field(default=-70, ge=-90, le=-40)
    max_recommendations: int = Field(default=3, ge=1, le=10)
    strategy: Literal["coverage_gap"] = "coverage_gap"
    band_preference: Literal["auto", "2.4GHz", "5GHz"] = "auto"
    include_channel_plan: bool = True


class APRecommendationItemOut(BaseModel):
    id: str
    x: float
    y: float
    band: Literal["2.4GHz", "5GHz"]
    channel: int
    tx_power: Literal["medium"]
    tx_power_fraction: float
    expected_rssi_dbm: int
    confidence: float
    reason: str
    covers_findings: list[Literal["dead_zone", "weak_zone", "overlap", "cci", "aci"]]
    warnings: list[str]


class APRecommendationOut(BaseModel):
    proyecto_id: int
    plano_id: int
    generated_at: datetime
    target_rssi_dbm: int
    strategy: Literal["coverage_gap"]
    recommendations: list[APRecommendationItemOut]
    assumptions: list[str]
    warnings: list[str]
