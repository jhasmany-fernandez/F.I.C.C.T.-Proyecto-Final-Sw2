from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class TechnicalReportIn(BaseModel):
    plano_id: int
    include_heatmap: bool = True
    include_coverage_analysis: bool = True
    include_ap_recommendations: bool = True
    metric: Literal["best_rssi", "avg_rssi"] = "best_rssi"
    target_rssi_dbm: int = Field(default=-70, ge=-90, le=-40)
    format: Literal["pdf"] = "pdf"
