from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

from app.schemas.ap_recommendation import (
    APRecommendationIn,
    APRecommendationItemOut,
    APRecommendationOut,
)
from app.schemas.coverage_analysis import CoverageAnalysisFindingOut
from app.services.coverage_analysis_service import CoverageAnalysisService

CLUSTER_RADIUS = 0.2
TX_POWER_FRACTION = 0.25
TOP_LEVEL_ASSUMPTIONS = [
    "No se modelaron paredes por material en esta versión.",
    "La potencia sugerida se mantiene entre 1/4 y 1/3 del máximo.",
    "La recomendación es heurística y debe validarse en sitio.",
]
CHANNELS_24 = [1, 6, 11]
CHANNELS_5 = [36, 40, 44, 48]


class APRecommendationError(Exception):
    pass


@dataclass
class CandidatePoint:
    x: float
    y: float
    finding_type: str
    severity: str


class APRecommendationService:
    def __init__(self, coverage_analysis_service: CoverageAnalysisService) -> None:
        self._coverage_analysis_service = coverage_analysis_service

    def recommend(
        self,
        *,
        proyecto_id: int,
        body: APRecommendationIn,
    ) -> APRecommendationOut:
        analysis = self._coverage_analysis_service.analyze(
            proyecto_id=proyecto_id,
            plano_id=body.plano_id,
            metric="best_rssi",
            include_heatmap_summary=True,
        )

        target_findings = [
            finding
            for finding in analysis.findings
            if finding.type in {"dead_zone", "weak_zone"}
        ]
        if not target_findings:
            return APRecommendationOut(
                proyecto_id=proyecto_id,
                plano_id=body.plano_id,
                generated_at=datetime.now(timezone.utc),
                target_rssi_dbm=body.target_rssi_dbm,
                strategy=body.strategy,
                recommendations=[],
                assumptions=TOP_LEVEL_ASSUMPTIONS,
                warnings=["La cobertura cumple el objetivo definido."],
            )

        candidates = self._build_candidates(target_findings)
        clusters = self._cluster_candidates(candidates)
        recommendations = self._build_recommendations(
            clusters=clusters,
            body=body,
            findings=analysis.findings,
            channel_analysis=analysis.channel_analysis,
            points_analyzed=analysis.summary.points_analyzed,
        )

        return APRecommendationOut(
            proyecto_id=proyecto_id,
            plano_id=body.plano_id,
            generated_at=datetime.now(timezone.utc),
            target_rssi_dbm=body.target_rssi_dbm,
            strategy=body.strategy,
            recommendations=recommendations[: body.max_recommendations],
            assumptions=TOP_LEVEL_ASSUMPTIONS,
            warnings=[],
        )

    def _build_candidates(
        self,
        findings: list[CoverageAnalysisFindingOut],
    ) -> list[CandidatePoint]:
        order = {"dead_zone": 0, "weak_zone": 1}
        sorted_findings = sorted(
            findings,
            key=lambda finding: (order.get(finding.type, 99), finding.punto_id),
        )
        return [
            CandidatePoint(
                x=finding.x,
                y=finding.y,
                finding_type=finding.type,
                severity=finding.severity,
            )
            for finding in sorted_findings
        ]

    def _cluster_candidates(
        self,
        candidates: list[CandidatePoint],
    ) -> list[list[CandidatePoint]]:
        clusters: list[list[CandidatePoint]] = []
        for candidate in candidates:
            assigned = False
            for cluster in clusters:
                centroid_x = sum(item.x for item in cluster) / len(cluster)
                centroid_y = sum(item.y for item in cluster) / len(cluster)
                if abs(candidate.x - centroid_x) <= CLUSTER_RADIUS and abs(candidate.y - centroid_y) <= CLUSTER_RADIUS:
                    cluster.append(candidate)
                    assigned = True
                    break
            if not assigned:
                clusters.append([candidate])
        return clusters

    def _build_recommendations(
        self,
        *,
        clusters: list[list[CandidatePoint]],
        body: APRecommendationIn,
        findings: list[CoverageAnalysisFindingOut],
        channel_analysis,
        points_analyzed: int,
    ) -> list[APRecommendationItemOut]:
        recommendations: list[APRecommendationItemOut] = []
        has_overlap = any(finding.type == "overlap" for finding in findings)
        has_cci = bool(channel_analysis.cci)
        has_aci = bool(channel_analysis.aci)

        for index, cluster in enumerate(clusters, start=1):
            x = max(0.0, min(1.0, sum(item.x for item in cluster) / len(cluster)))
            y = max(0.0, min(1.0, sum(item.y for item in cluster) / len(cluster)))
            cluster_types = {item.finding_type for item in cluster}
            band = self._select_band(
                body=body,
                points_analyzed=points_analyzed,
                has_cci=has_cci,
                has_aci=has_aci,
            )
            channel = self._select_channel(
                band=band,
                include_channel_plan=body.include_channel_plan,
                channel_analysis=channel_analysis,
            )
            covers_findings = sorted(cluster_types)
            if has_overlap:
                covers_findings.append("overlap")
            if has_cci:
                covers_findings.append("cci")
            if has_aci:
                covers_findings.append("aci")
            covers_findings = list(dict.fromkeys(covers_findings))

            confidence = self._compute_confidence(
                cluster_size=len(cluster),
                points_analyzed=points_analyzed,
                has_dead_zone="dead_zone" in cluster_types,
            )
            warnings = []
            if points_analyzed <= 1:
                warnings.append("Poca evidencia: solo hay un punto analizado.")
            elif points_analyzed < 3:
                warnings.append("Cobertura estimada con pocos puntos medidos.")

            reason = self._build_reason(
                cluster_types=cluster_types,
                has_overlap=has_overlap,
                has_cci=has_cci,
                has_aci=has_aci,
                band=band,
                channel=channel,
            )
            recommendations.append(
                APRecommendationItemOut(
                    id=f"ap-rec-{index}",
                    x=round(x, 4),
                    y=round(y, 4),
                    band=band,  # type: ignore[arg-type]
                    channel=channel,
                    tx_power="medium",
                    tx_power_fraction=TX_POWER_FRACTION,
                    expected_rssi_dbm=min(body.target_rssi_dbm + 3, -55),
                    confidence=round(confidence, 2),
                    reason=reason,
                    covers_findings=covers_findings,  # type: ignore[arg-type]
                    warnings=warnings,
                )
            )

        return recommendations

    def _select_band(
        self,
        *,
        body: APRecommendationIn,
        points_analyzed: int,
        has_cci: bool,
        has_aci: bool,
    ) -> str:
        if body.band_preference != "auto":
            return body.band_preference
        if points_analyzed >= 3 or has_cci or has_aci:
            return "5GHz"
        return "2.4GHz"

    def _select_channel(
        self,
        *,
        band: str,
        include_channel_plan: bool,
        channel_analysis,
    ) -> int:
        if not include_channel_plan:
            return 36 if band == "5GHz" else 1

        conflict_channels = {
            item.channel for item in channel_analysis.cci
        } | {
            item.channel for item in channel_analysis.aci
        } | {
            item.adjacent_to for item in channel_analysis.aci
        }
        candidates = CHANNELS_5 if band == "5GHz" else CHANNELS_24
        for channel in candidates:
            if channel not in conflict_channels:
                return channel
        return candidates[0]

    def _compute_confidence(
        self,
        *,
        cluster_size: int,
        points_analyzed: int,
        has_dead_zone: bool,
    ) -> float:
        if points_analyzed <= 1:
            confidence = 0.42
        elif points_analyzed < 4:
            confidence = 0.63
        else:
            confidence = 0.78
        confidence += min(cluster_size, 3) * 0.04
        if has_dead_zone:
            confidence += 0.08
        return max(0.0, min(0.95, confidence))

    def _build_reason(
        self,
        *,
        cluster_types: set[str],
        has_overlap: bool,
        has_cci: bool,
        has_aci: bool,
        band: str,
        channel: int,
    ) -> str:
        base_parts: list[str] = []
        if "dead_zone" in cluster_types:
            base_parts.append("Cubre zona muerta cercana")
        if "weak_zone" in cluster_types:
            base_parts.append("refuerza zona débil")
        if not base_parts:
            base_parts.append("Mejora cobertura observada")

        interference_parts: list[str] = []
        if has_overlap:
            interference_parts.append("reduce solapamiento")
        if has_cci or has_aci:
            interference_parts.append(f"evita conflictos usando canal {channel} en {band}")

        sentence = " y ".join(base_parts)
        if interference_parts:
            sentence = f"{sentence} y {' y '.join(interference_parts)}."
        else:
            sentence = f"{sentence}."
        return sentence
