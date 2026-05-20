from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field, field_validator


class WifiScanSenalIn(BaseModel):
    ssid: str | None = Field(default=None, max_length=255)
    bssid: str = Field(..., min_length=17, max_length=17)
    rssi_dbm: int = Field(..., ge=-100, le=0)
    frequency_mhz: int | None = Field(default=None, gt=0)
    channel: int | None = None
    security: str | None = Field(default=None, max_length=255)

    @field_validator("bssid")
    @classmethod
    def validar_bssid(cls, value: str) -> str:
        import re

        if not re.fullmatch(r"(?i)[0-9a-f]{2}(:[0-9a-f]{2}){5}", value):
            raise ValueError("BSSID inválido. Debe tener formato MAC.")
        return value.upper()


class WifiScanLoteIn(BaseModel):
    plano_id: int
    punto_id: str | int | None = Field(default=None)
    capturado_en: datetime
    origen: str = Field(default="mobile", min_length=1, max_length=30)
    app_version: str | None = Field(default=None, max_length=50)
    device_id: str | None = Field(default=None, max_length=120)
    senales: list[WifiScanSenalIn] = Field(..., min_length=1, max_length=200)

    @field_validator("punto_id")
    @classmethod
    def validar_punto_id(cls, value: str | int | None) -> str | int | None:
        if value is None:
            return None
        if isinstance(value, str) and len(value) > 100:
            raise ValueError("punto_id no puede exceder 100 caracteres.")
        return value


class WifiScanLoteOut(BaseModel):
    id: int
    proyecto_id: int
    plano_id: int
    punto_id: str | None
    capturado_en: datetime
    tecnico_id: int
    origen: str
    cantidad_senales: int
    created_at: datetime
