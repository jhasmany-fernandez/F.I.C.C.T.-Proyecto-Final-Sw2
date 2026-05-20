from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class CoverageAnalysisSummaryOut(BaseModel):
    points_analyzed: int
    dead_zones_count: int
    weak_zones_count: int
    coverage_ok_count: int
    coverage_ok_percent: float
    avg_rssi_dbm: float
    best_rssi_dbm: float
    worst_rssi_dbm: float


class CoverageAnalysisFindingOut(BaseModel):
    type: Literal["dead_zone", "weak_zone", "overlap"]
    severity: Literal["critical", "high", "medium", "low"]
    message: str
    punto_id: int
    x: float
    y: float
    rssi_dbm: float
    recommendation: str


class CoverageAnalysisCCIOut(BaseModel):
    channel: int
    frequency_mhz: int | None
    severity: Literal["critical", "high", "medium", "low"]
    bssid_count: int
    bssids: list[str]
    recommendation: str


class CoverageAnalysisACIOut(BaseModel):
    channel: int
    adjacent_to: int
    severity: Literal["critical", "high", "medium", "low"]
    recommendation: str


class CoverageAnalysisChannelOut(BaseModel):
    cci: list[CoverageAnalysisCCIOut]
    aci: list[CoverageAnalysisACIOut]


class CoverageHeatmapSummaryOut(BaseModel):
    metric: Literal["best_rssi", "avg_rssi"]
    min_rssi: int
    max_rssi: int
    points_used: int
    warning: str | None


class CoverageAnalysisOut(BaseModel):
    proyecto_id: int
    plano_id: int
    generated_at: datetime
    objective_rssi_dbm: int
    dead_zone_threshold_dbm: int
    metric: Literal["best_rssi", "avg_rssi"]
    summary: CoverageAnalysisSummaryOut
    findings: list[CoverageAnalysisFindingOut]
    channel_analysis: CoverageAnalysisChannelOut
    heatmap_summary: CoverageHeatmapSummaryOut | None = None
