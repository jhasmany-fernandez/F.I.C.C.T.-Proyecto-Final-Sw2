from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.punto_medicion import PuntoMedicion
from app.models.wifi_scan import WifiScanLote, WifiScanSenal
from app.schemas.coverage_analysis import (
    CoverageAnalysisACIOut,
    CoverageAnalysisCCIOut,
    CoverageAnalysisChannelOut,
    CoverageAnalysisFindingOut,
    CoverageAnalysisOut,
    CoverageAnalysisSummaryOut,
    CoverageHeatmapSummaryOut,
)
from app.services.heatmap_service import MAX_RSSI, MIN_RSSI

OBJECTIVE_RSSI = -70
DEAD_ZONE_THRESHOLD = -90
OVERLAP_STRONG_RSSI = -67
CCI_RELEVANT_RSSI = -80
ACI_24GHZ_MAX_CHANNEL_DELTA = 4
ACI_5GHZ_MAX_FREQUENCY_DELTA = 40


class CoverageAnalysisError(Exception):
    pass


@dataclass
class PointCoverageStats:
    punto_id: int
    x: float
    y: float
    best_rssi: float
    avg_rssi: float
    worst_rssi: float
    best_bssid: str | None
    strong_bssid_count: int
    selected_metric_rssi: float
    channels: list[int]
    frequencies: list[int]


class CoverageAnalysisService:
    def __init__(self, db: Session) -> None:
        self._db = db

    def analyze(
        self,
        *,
        proyecto_id: int,
        plano_id: int,
        metric: str,
        ssid: str | None = None,
        bssid: str | None = None,
        include_heatmap_summary: bool = False,
    ) -> CoverageAnalysisOut:
        puntos = self._db.query(PuntoMedicion).filter(
            PuntoMedicion.proyecto_id == proyecto_id,
            PuntoMedicion.plano_id == plano_id,
        ).all()
        if not puntos:
            raise CoverageAnalysisError("El proyecto no tiene puntos de medición.")

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
            raise CoverageAnalysisError("El proyecto no tiene mediciones WiFi asociadas a puntos.")

        lote_ids = [lote_id for ids in lotes_by_punto.values() for lote_id in ids]
        signals_query = self._db.query(WifiScanSenal).filter(WifiScanSenal.lote_id.in_(lote_ids))
        if ssid is not None:
            signals_query = signals_query.filter(WifiScanSenal.ssid == ssid)
        if bssid is not None:
            signals_query = signals_query.filter(WifiScanSenal.bssid == bssid.upper())
        signals = signals_query.all()
        if not signals:
            raise CoverageAnalysisError("No hay mediciones WiFi para los filtros solicitados.")

        signals_by_lote: dict[int, list[WifiScanSenal]] = {}
        for signal in signals:
            signals_by_lote.setdefault(signal.lote_id, []).append(signal)

        point_stats: list[PointCoverageStats] = []
        point_signals: dict[int, list[WifiScanSenal]] = {}
        for punto_id, punto_lote_ids in lotes_by_punto.items():
            punto_signals_list = [
                signal
                for lote_id in punto_lote_ids
                for signal in signals_by_lote.get(lote_id, [])
            ]
            if not punto_signals_list:
                continue
            stats = self._build_point_stats(
                punto=puntos_by_id[punto_id],
                signals=punto_signals_list,
                metric=metric,
            )
            point_stats.append(stats)
            point_signals[punto_id] = punto_signals_list

        if not point_stats:
            raise CoverageAnalysisError("No hay mediciones WiFi asociadas a puntos.")

        summary = self._build_summary(point_stats=point_stats)
        findings = self._build_findings(point_stats=point_stats, point_signals=point_signals)
        channel_analysis = self._build_channel_analysis(signals=signals)
        heatmap_summary = None
        if include_heatmap_summary:
            heatmap_summary = CoverageHeatmapSummaryOut(
                metric=metric,  # type: ignore[arg-type]
                min_rssi=MIN_RSSI,
                max_rssi=MAX_RSSI,
                points_used=len(point_stats),
                warning=(
                    "Heatmap aproximado: menos de 3 puntos disponibles."
                    if len(point_stats) < 3
                    else None
                ),
            )

        return CoverageAnalysisOut(
            proyecto_id=proyecto_id,
            plano_id=plano_id,
            generated_at=datetime.now(timezone.utc),
            objective_rssi_dbm=OBJECTIVE_RSSI,
            dead_zone_threshold_dbm=DEAD_ZONE_THRESHOLD,
            metric=metric,  # type: ignore[arg-type]
            summary=summary,
            findings=findings,
            channel_analysis=channel_analysis,
            heatmap_summary=heatmap_summary,
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

    def _build_point_stats(
        self,
        *,
        punto: PuntoMedicion,
        signals: list[WifiScanSenal],
        metric: str,
    ) -> PointCoverageStats:
        rssis = [signal.rssi_dbm for signal in signals]
        best_signal = max(signals, key=lambda signal: signal.rssi_dbm)
        best_rssi = float(max(rssis))
        avg_rssi = float(sum(rssis) / len(rssis))
        worst_rssi = float(min(rssis))
        selected_metric_rssi = best_rssi if metric == "best_rssi" else avg_rssi
        strong_bssids = {
            signal.bssid
            for signal in signals
            if signal.rssi_dbm >= OVERLAP_STRONG_RSSI
        }
        channels = sorted({signal.channel for signal in signals if signal.channel is not None})
        frequencies = sorted(
            {signal.frequency_mhz for signal in signals if signal.frequency_mhz is not None}
        )
        return PointCoverageStats(
            punto_id=punto.id,
            x=float(punto.x),
            y=float(punto.y),
            best_rssi=best_rssi,
            avg_rssi=avg_rssi,
            worst_rssi=worst_rssi,
            best_bssid=best_signal.bssid if best_signal else None,
            strong_bssid_count=len(strong_bssids),
            selected_metric_rssi=selected_metric_rssi,
            channels=channels,
            frequencies=frequencies,
        )

    def _build_summary(
        self,
        *,
        point_stats: list[PointCoverageStats],
    ) -> CoverageAnalysisSummaryOut:
        values = [stats.selected_metric_rssi for stats in point_stats]
        dead_count = len([value for value in values if value < DEAD_ZONE_THRESHOLD])
        weak_count = len(
            [value for value in values if DEAD_ZONE_THRESHOLD <= value < OBJECTIVE_RSSI]
        )
        ok_count = len([value for value in values if value >= OBJECTIVE_RSSI])
        points_analyzed = len(values)
        coverage_ok_percent = (ok_count / points_analyzed) * 100 if points_analyzed else 0.0
        return CoverageAnalysisSummaryOut(
            points_analyzed=points_analyzed,
            dead_zones_count=dead_count,
            weak_zones_count=weak_count,
            coverage_ok_count=ok_count,
            coverage_ok_percent=round(coverage_ok_percent, 2),
            avg_rssi_dbm=round(sum(values) / points_analyzed, 2),
            best_rssi_dbm=round(max(values), 2),
            worst_rssi_dbm=round(min(values), 2),
        )

    def _build_findings(
        self,
        *,
        point_stats: list[PointCoverageStats],
        point_signals: dict[int, list[WifiScanSenal]],
    ) -> list[CoverageAnalysisFindingOut]:
        findings: list[CoverageAnalysisFindingOut] = []
        for stats in point_stats:
            rssi = stats.selected_metric_rssi
            if rssi < DEAD_ZONE_THRESHOLD:
                findings.append(
                    CoverageAnalysisFindingOut(
                        type="dead_zone",
                        severity="critical",
                        message="Zona muerta detectada: RSSI menor a -90 dBm.",
                        punto_id=stats.punto_id,
                        x=round(stats.x, 4),
                        y=round(stats.y, 4),
                        rssi_dbm=round(rssi, 2),
                        recommendation="Agregar o reubicar un AP cercano.",
                    )
                )
            elif rssi < OBJECTIVE_RSSI:
                findings.append(
                    CoverageAnalysisFindingOut(
                        type="weak_zone",
                        severity="high",
                        message="Zona débil detectada: RSSI por debajo del objetivo de -70 dBm.",
                        punto_id=stats.punto_id,
                        x=round(stats.x, 4),
                        y=round(stats.y, 4),
                        rssi_dbm=round(rssi, 2),
                        recommendation="Mejorar potencia, densidad o ubicación de APs.",
                    )
                )

            if stats.strong_bssid_count >= 2:
                severity = "high" if stats.strong_bssid_count >= 3 else "medium"
                findings.append(
                    CoverageAnalysisFindingOut(
                        type="overlap",
                        severity=severity,
                        message="Solapamiento detectado: múltiples BSSID fuertes en el mismo punto.",
                        punto_id=stats.punto_id,
                        x=round(stats.x, 4),
                        y=round(stats.y, 4),
                        rssi_dbm=round(rssi, 2),
                        recommendation="Revisar potencia y celdas para reducir solapamiento excesivo.",
                    )
                )
        return findings

    def _build_channel_analysis(
        self,
        *,
        signals: list[WifiScanSenal],
    ) -> CoverageAnalysisChannelOut:
        relevant_signals = [
            signal
            for signal in signals
            if signal.channel is not None and signal.rssi_dbm >= CCI_RELEVANT_RSSI
        ]

        by_channel: dict[int, list[WifiScanSenal]] = {}
        for signal in relevant_signals:
            by_channel.setdefault(signal.channel, []).append(signal)

        cci: list[CoverageAnalysisCCIOut] = []
        for channel, channel_signals in sorted(by_channel.items()):
            bssids = sorted({signal.bssid for signal in channel_signals})
            if len(bssids) < 2:
                continue
            frequencies = [signal.frequency_mhz for signal in channel_signals if signal.frequency_mhz]
            severity = "high" if len(bssids) >= 3 else "medium"
            cci.append(
                CoverageAnalysisCCIOut(
                    channel=channel,
                    frequency_mhz=min(frequencies) if frequencies else None,
                    severity=severity,
                    bssid_count=len(bssids),
                    bssids=bssids,
                    recommendation="Reducir APs en el mismo canal o cambiar canal.",
                )
            )

        aci: list[CoverageAnalysisACIOut] = []
        seen_pairs: set[tuple[int, int]] = set()
        channel_items = sorted(by_channel.items())
        for index, (channel_a, signals_a) in enumerate(channel_items):
            for channel_b, signals_b in channel_items[index + 1 :]:
                if self._is_adjacent_interference(
                    channel_a=channel_a,
                    signals_a=signals_a,
                    channel_b=channel_b,
                    signals_b=signals_b,
                ):
                    pair = (min(channel_a, channel_b), max(channel_a, channel_b))
                    if pair in seen_pairs:
                        continue
                    seen_pairs.add(pair)
                    aci.append(
                        CoverageAnalysisACIOut(
                            channel=pair[0],
                            adjacent_to=pair[1],
                            severity="low",
                            recommendation="Revisar planificación de canales.",
                        )
                    )

        return CoverageAnalysisChannelOut(cci=cci, aci=aci)

    def _is_adjacent_interference(
        self,
        *,
        channel_a: int,
        signals_a: list[WifiScanSenal],
        channel_b: int,
        signals_b: list[WifiScanSenal],
    ) -> bool:
        frequencies_a = [signal.frequency_mhz for signal in signals_a if signal.frequency_mhz]
        frequencies_b = [signal.frequency_mhz for signal in signals_b if signal.frequency_mhz]
        if not frequencies_a or not frequencies_b:
            return False

        freq_a = min(frequencies_a)
        freq_b = min(frequencies_b)
        if freq_a < 3000 and freq_b < 3000:
            return 0 < abs(channel_a - channel_b) <= ACI_24GHZ_MAX_CHANNEL_DELTA
        if freq_a >= 5000 and freq_b >= 5000:
            return abs(freq_a - freq_b) <= ACI_5GHZ_MAX_FREQUENCY_DELTA
        return False
