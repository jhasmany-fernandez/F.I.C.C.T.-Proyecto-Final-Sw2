from __future__ import annotations

from io import BytesIO

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

from app.models.proyecto import Proyecto
from app.models.usuario import Usuario
from app.schemas.ap_recommendation import APRecommendationIn, APRecommendationOut
from app.schemas.coverage_analysis import CoverageAnalysisOut
from app.schemas.heatmap import HeatmapOut
from app.schemas.technical_report import TechnicalReportIn
from app.services.ap_recommendation_service import APRecommendationService
from app.services.coverage_analysis_service import CoverageAnalysisService
from app.services.heatmap_service import HeatmapService


class TechnicalReportService:
    def __init__(
        self,
        *,
        heatmap_service: HeatmapService,
        coverage_analysis_service: CoverageAnalysisService,
        ap_recommendation_service: APRecommendationService,
    ) -> None:
        self._heatmap_service = heatmap_service
        self._coverage_analysis_service = coverage_analysis_service
        self._ap_recommendation_service = ap_recommendation_service

    def generate(
        self,
        *,
        proyecto: Proyecto,
        current_user: Usuario,
        body: TechnicalReportIn,
    ) -> bytes:
        coverage_analysis = self._coverage_analysis_service.analyze(
            proyecto_id=proyecto.id,
            plano_id=body.plano_id,
            metric=body.metric,
            include_heatmap_summary=body.include_heatmap,
        )
        heatmap = None
        if body.include_heatmap:
            heatmap = self._heatmap_service.generate(
                proyecto_id=proyecto.id,
                plano_id=body.plano_id,
                resolution=50,
                metric=body.metric,
            )

        ap_recommendations = None
        if body.include_ap_recommendations:
            ap_recommendations = self._ap_recommendation_service.recommend(
                proyecto_id=proyecto.id,
                body=APRecommendationIn(
                    plano_id=body.plano_id,
                    target_rssi_dbm=body.target_rssi_dbm,
                    strategy="coverage_gap",
                    band_preference="auto",
                    include_channel_plan=True,
                    max_recommendations=3,
                ),
            )

        return self._build_pdf(
            proyecto=proyecto,
            current_user=current_user,
            body=body,
            coverage_analysis=coverage_analysis,
            heatmap=heatmap,
            ap_recommendations=ap_recommendations,
        )

    def _build_pdf(
        self,
        *,
        proyecto: Proyecto,
        current_user: Usuario,
        body: TechnicalReportIn,
        coverage_analysis: CoverageAnalysisOut,
        heatmap: HeatmapOut | None,
        ap_recommendations: APRecommendationOut | None,
    ) -> bytes:
        buffer = BytesIO()
        pdf = canvas.Canvas(buffer, pagesize=A4, pageCompression=0)
        width, height = A4
        y = height - 50

        def section(title: str) -> None:
            nonlocal y
            y = self._ensure_space(pdf, y, 72)
            pdf.setFont("Helvetica-Bold", 15)
            pdf.drawString(50, y, title)
            y -= 22
            pdf.setFont("Helvetica", 10)

        def line(text: str, indent: int = 0) -> None:
            nonlocal y
            y = self._ensure_space(pdf, y, 22)
            pdf.drawString(50 + indent, y, text[:150])
            y -= 14

        pdf.setTitle(f"wireless-heatmapper-proyecto-{proyecto.id}.pdf")
        pdf.setAuthor("Wireless HeatMapper")
        pdf.setFont("Helvetica-Bold", 20)
        pdf.drawString(50, y, "Wireless HeatMapper")
        y -= 28
        pdf.setFont("Helvetica-Bold", 16)
        pdf.drawString(50, y, "Reporte tecnico de cobertura WiFi")
        y -= 30
        pdf.setFont("Helvetica", 11)
        line(f"Proyecto: {proyecto.nombre}")
        line(f"Cliente: {proyecto.cliente.nombre if proyecto.cliente else 'Sin cliente'}")
        line(f"Fecha de generación: {coverage_analysis.generated_at.isoformat()}")
        line(f"Generado por: {current_user.nombre} ({current_user.rol})")

        section("Resumen ejecutivo")
        summary = coverage_analysis.summary
        line(f"Puntos analizados: {summary.points_analyzed}")
        line(f"Cobertura OK %: {summary.coverage_ok_percent}")
        line(f"Zonas muertas: {summary.dead_zones_count}")
        line(f"Zonas débiles: {summary.weak_zones_count}")
        line(f"RSSI promedio: {summary.avg_rssi_dbm} dBm")
        line(f"Mejor RSSI: {summary.best_rssi_dbm} dBm")
        line(f"Peor RSSI: {summary.worst_rssi_dbm} dBm")

        section("Plano")
        plano = proyecto.plano
        if plano is not None:
            line(f"Plano ID: {plano.id}")
            line(f"Nombre: {plano.nombre_archivo}")
            line(f"Tipo MIME: {plano.mime_type}")
            line(f"Tamaño: {plano.size_bytes} bytes")

        if body.include_heatmap and heatmap is not None:
            section("Heatmap")
            line(f"Métrica: {heatmap.metric}")
            line("Resolution usada: 50")
            line(f"Puntos usados: {heatmap.points_used}")
            line(f"RSSI mínimo: {heatmap.min_rssi}")
            line(f"RSSI máximo: {heatmap.max_rssi}")
            if heatmap.warning:
                line(f"Warning: {heatmap.warning}")

        if body.include_coverage_analysis:
            section("Analisis de cobertura")
            if not coverage_analysis.findings:
                line("Sin hallazgos críticos.")
            else:
                for finding in coverage_analysis.findings:
                    line(
                        f"{finding.type} | severidad={finding.severity} | punto={finding.punto_id} | rssi={finding.rssi_dbm}"
                    )
                    line(f"Mensaje: {finding.message}", 10)
                    line(f"Recomendación: {finding.recommendation}", 10)
            if coverage_analysis.channel_analysis.cci:
                line("CCI detectado:")
                for cci in coverage_analysis.channel_analysis.cci:
                    line(
                        f"Canal {cci.channel} | BSSID={cci.bssid_count} | severidad={cci.severity}",
                        10,
                    )
            if coverage_analysis.channel_analysis.aci:
                line("ACI detectado:")
                for aci in coverage_analysis.channel_analysis.aci:
                    line(
                        f"Canales {aci.channel}-{aci.adjacent_to} | severidad={aci.severity}",
                        10,
                    )

        if body.include_ap_recommendations and ap_recommendations is not None:
            section("Recomendaciones de APs")
            if not ap_recommendations.recommendations:
                for warning in ap_recommendations.warnings:
                    line(f"Warning: {warning}")
            else:
                for recommendation in ap_recommendations.recommendations:
                    line(
                        f"{recommendation.id} | x={recommendation.x} y={recommendation.y} | {recommendation.band} canal {recommendation.channel}"
                    )
                    line(
                        f"Potencia: {recommendation.tx_power} ({recommendation.tx_power_fraction}) | RSSI esperado: {recommendation.expected_rssi_dbm}",
                        10,
                    )
                    line(
                        f"Confianza: {recommendation.confidence} | Razón: {recommendation.reason}",
                        10,
                    )
                    if recommendation.warnings:
                        line(
                            f"Warnings: {', '.join(recommendation.warnings)}",
                            10,
                        )

        section("Supuestos y limitaciones")
        line("No se modelan paredes/materiales en esta versión.")
        line("No se usa calibración PB-11 todavía.")
        line("Las recomendaciones son heurísticas.")
        line("Validar en sitio.")

        pdf.save()
        return buffer.getvalue()

    def _ensure_space(self, pdf: canvas.Canvas, y: float, threshold: float) -> float:
        if y < threshold:
            pdf.showPage()
            pdf.setFont("Helvetica", 10)
            return A4[1] - 50
        return y
