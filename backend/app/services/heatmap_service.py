from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from math import sqrt

from sqlalchemy.orm import Session

from app.models.punto_medicion import PuntoMedicion
from app.models.wifi_scan import WifiScanLote, WifiScanSenal
from app.schemas.heatmap import HeatmapCellOut, HeatmapOut

MIN_RSSI = -90
MAX_RSSI = -35
DIRECT_DISTANCE_THRESHOLD = 1e-9
IDW_POWER = 2


class HeatmapError(Exception):
    pass


@dataclass
class HeatmapPointValue:
    punto_id: int
    x: float
    y: float
    rssi_dbm: float


class HeatmapService:
    def __init__(self, db: Session) -> None:
        self._db = db

    def generate(
        self,
        *,
        proyecto_id: int,
        plano_id: int,
        resolution: int,
        metric: str,
        ssid: str | None = None,
        bssid: str | None = None,
    ) -> HeatmapOut:
        puntos = self._db.query(PuntoMedicion).filter(
            PuntoMedicion.proyecto_id == proyecto_id,
            PuntoMedicion.plano_id == plano_id,
        ).all()
        if not puntos:
            raise HeatmapError("El proyecto no tiene puntos de medición.")

        puntos_by_id = {p.id: p for p in puntos}
        lotes = self._db.query(WifiScanLote).filter(
            WifiScanLote.proyecto_id == proyecto_id,
            WifiScanLote.plano_id == plano_id,
        ).all()

        lotes_by_punto: dict[int, list[int]] = {}
        for lote in lotes:
            punto_real_id = self._resolve_point_for_lote(
                lote=lote,
                puntos_by_id=puntos_by_id,
                plano_id=plano_id,
            )
            if punto_real_id is None:
                continue
            lotes_by_punto.setdefault(punto_real_id, []).append(lote.id)

        if not lotes_by_punto:
            raise HeatmapError("El proyecto no tiene mediciones WiFi asociadas a puntos.")

        lote_ids = [lote_id for ids in lotes_by_punto.values() for lote_id in ids]
        signals_query = self._db.query(WifiScanSenal).filter(WifiScanSenal.lote_id.in_(lote_ids))
        if ssid is not None:
            signals_query = signals_query.filter(WifiScanSenal.ssid == ssid)
        if bssid is not None:
            signals_query = signals_query.filter(WifiScanSenal.bssid == bssid.upper())
        signals = signals_query.all()
        if not signals:
            raise HeatmapError("No hay mediciones WiFi para los filtros solicitados.")

        signals_by_lote: dict[int, list[WifiScanSenal]] = {}
        for signal in signals:
            signals_by_lote.setdefault(signal.lote_id, []).append(signal)

        point_values: list[HeatmapPointValue] = []
        for punto_id, punto_lote_ids in lotes_by_punto.items():
            rssis = [
                signal.rssi_dbm
                for lote_id in punto_lote_ids
                for signal in signals_by_lote.get(lote_id, [])
            ]
            if not rssis:
                continue
            value = max(rssis) if metric == "best_rssi" else (sum(rssis) / len(rssis))
            punto = puntos_by_id[punto_id]
            point_values.append(
                HeatmapPointValue(
                    punto_id=punto_id,
                    x=punto.x,
                    y=punto.y,
                    rssi_dbm=float(value),
                )
            )

        if not point_values:
            raise HeatmapError("No hay mediciones WiFi asociadas a puntos.")

        warning = None
        if len(point_values) < 3:
            warning = "Heatmap aproximado: menos de 3 puntos disponibles."

        grid = self._build_grid(point_values=point_values, resolution=resolution)
        return HeatmapOut(
            proyecto_id=proyecto_id,
            plano_id=plano_id,
            metric=metric,  # type: ignore[arg-type]
            resolution=resolution,
            min_rssi=MIN_RSSI,
            max_rssi=MAX_RSSI,
            generated_at=datetime.now(timezone.utc),
            points_used=len(point_values),
            warning=warning,
            grid=grid,
        )

    def _resolve_point_for_lote(
        self,
        *,
        lote: WifiScanLote,
        puntos_by_id: dict[int, PuntoMedicion],
        plano_id: int,
    ) -> int | None:
        if lote.punto_medicion_id is not None and lote.punto_medicion_id in puntos_by_id:
            return lote.punto_medicion_id
        if lote.punto_id and lote.punto_id.isdigit():
            legacy_id = int(lote.punto_id)
            punto = puntos_by_id.get(legacy_id)
            if punto is not None and punto.plano_id == plano_id:
                return legacy_id
        return None

    def _build_grid(
        self,
        *,
        point_values: list[HeatmapPointValue],
        resolution: int,
    ) -> list[HeatmapCellOut]:
        if resolution == 1:
            coords = [0.0]
        else:
            coords = [i / (resolution - 1) for i in range(resolution)]

        grid: list[HeatmapCellOut] = []
        for y in coords:
            for x in coords:
                rssi = self._interpolate_rssi(x=x, y=y, point_values=point_values)
                normalized = self._normalize_rssi(rssi)
                grid.append(
                    HeatmapCellOut(
                        x=round(x, 4),
                        y=round(y, 4),
                        rssi_dbm=round(rssi, 2),
                        normalized=round(normalized, 4),
                        color=self._to_color(normalized),
                    )
                )
        return grid

    def _interpolate_rssi(
        self,
        *,
        x: float,
        y: float,
        point_values: list[HeatmapPointValue],
    ) -> float:
        numerator = 0.0
        denominator = 0.0
        for point in point_values:
            dx = point.x - x
            dy = point.y - y
            distance = sqrt((dx * dx) + (dy * dy))
            if distance <= DIRECT_DISTANCE_THRESHOLD:
                return point.rssi_dbm
            weight = 1 / (distance**IDW_POWER)
            numerator += point.rssi_dbm * weight
            denominator += weight
        return numerator / denominator

    def _normalize_rssi(self, rssi: float) -> float:
        normalized = (rssi - MIN_RSSI) / (MAX_RSSI - MIN_RSSI)
        return max(0.0, min(1.0, normalized))

    def _to_color(self, normalized: float) -> str:
        if normalized <= 0.5:
            ratio = normalized / 0.5
            red = 255
            green = int(255 * ratio)
        else:
            ratio = (normalized - 0.5) / 0.5
            red = int(255 * (1 - ratio))
            green = 255
        blue = 0
        return f"#{red:02X}{green:02X}{blue:02X}"
