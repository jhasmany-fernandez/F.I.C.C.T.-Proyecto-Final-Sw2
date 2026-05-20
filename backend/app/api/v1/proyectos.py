"""Endpoints de proyectos para el técnico autenticado.

PB-09 — Sprint 1: pantalla inicial «Mis Proyectos» de la app móvil.
PB-01 — Sprint 1: CRUD completo de proyectos (crear, editar, archivar, eliminar).
Tags OpenAPI: proyectos
"""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse, Response
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.plano import Plano
from app.models.proyecto import Proyecto
from app.models.usuario import Usuario
from app.repositories.punto_medicion_repository import PuntoMedicionRepository
from app.repositories.proyecto_repository import ProyectoRepository
from app.repositories.wifi_scan_repository import WifiScanRepository
from app.schemas.ap_recommendation import APRecommendationIn, APRecommendationOut
from app.schemas.coverage_analysis import CoverageAnalysisOut
from app.schemas.heatmap import HeatmapOut
from app.schemas.punto_medicion import PuntoMedicionIn, PuntoMedicionOut
from app.schemas.plano import PlanoOut
from app.schemas.proyecto import ProyectoIn, ProyectoTecnicoOut
from app.schemas.technical_report import TechnicalReportIn
from app.schemas.wifi_scan import WifiScanLoteIn, WifiScanLoteOut
from app.services.coverage_analysis_service import (
    CoverageAnalysisError,
    CoverageAnalysisService,
)
from app.services.ap_recommendation_service import APRecommendationService
from app.services.heatmap_service import HeatmapError, HeatmapService
from app.services.plano_storage import PlanoStorageService, PlanoValidationError
from app.services.technical_report_service import TechnicalReportService

router = APIRouter(prefix="/proyectos", tags=["proyectos"])


def _obtener_proyecto_propio_o_error(
    *,
    repo: ProyectoRepository,
    proyecto_id: int,
    tecnico_id: int,
) -> Proyecto:
    proyecto = repo.obtener_por_id(proyecto_id=proyecto_id, tecnico_id=tecnico_id)
    if proyecto is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Proyecto no encontrado.",
        )
    if proyecto.estado == "archivado":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El proyecto está archivado.",
        )
    return proyecto


def _obtener_proyecto_propio_para_consulta_o_error(
    *,
    repo: ProyectoRepository,
    proyecto_id: int,
    current_user: Usuario,
) -> Proyecto:
    proyecto = repo.obtener_por_id_visible(
        proyecto_id=proyecto_id,
        current_user=current_user,
    )
    if proyecto is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Proyecto no encontrado.",
        )
    return proyecto


def _resolver_punto_wifi_scan(
    *,
    repo: PuntoMedicionRepository,
    proyecto_id: int,
    plano_id: int,
    punto_id_raw: str | int | None,
):
    if punto_id_raw is None:
        return None, None

    punto_id_legacy = str(punto_id_raw)
    punto_medicion = None
    punto_id_numerico: int | None = None

    if isinstance(punto_id_raw, int):
        punto_id_numerico = punto_id_raw
    elif isinstance(punto_id_raw, str) and punto_id_raw.isdigit():
        punto_id_numerico = int(punto_id_raw)

    if punto_id_numerico is None:
        return punto_id_legacy, None

    punto_medicion = repo.obtener_por_id(
        proyecto_id=proyecto_id,
        punto_id=punto_id_numerico,
    )
    if punto_medicion is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Punto de medición no encontrado.",
        )
    if punto_medicion.plano_id != plano_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El punto de medición no pertenece al plano indicado.",
        )
    return punto_id_legacy, punto_medicion


@router.get(
    "",
    response_model=list[ProyectoTecnicoOut],
    summary="Listar mis proyectos",
    description=(
        "Retorna los proyectos activos del técnico autenticado, ordenados por "
        "última actividad descendente. Sin filtro de estado excluye los archivados. "
        "PB-09 — CA-1."
    ),
)
def listar_mis_proyectos(
    estado: str | None = Query(
        default=None,
        description="Filtrar por estado (en_progreso, completado, archivado)",
    ),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> list[ProyectoTecnicoOut]:
    repo = ProyectoRepository(db)
    proyectos = repo.listar_por_tecnico(
        tecnico_id=current_user.id,
        estado=estado,
    )
    return [ProyectoTecnicoOut.from_proyecto(p) for p in proyectos]


@router.post(
    "",
    response_model=ProyectoTecnicoOut,
    status_code=status.HTTP_201_CREATED,
    summary="Crear proyecto",
    description="Crea un nuevo proyecto de survey para el técnico autenticado. PB-01 — CA-1.",
)
def crear_proyecto(
    body: ProyectoIn,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> ProyectoTecnicoOut:
    repo = ProyectoRepository(db)
    proyecto = repo.crear(
        nombre=body.nombre,
        tecnico_id=current_user.id,
        cliente_id=body.cliente_id,
        descripcion=body.descripcion,
    )
    return ProyectoTecnicoOut.from_proyecto(proyecto)


@router.put(
    "/{proyecto_id}",
    response_model=ProyectoTecnicoOut,
    summary="Actualizar proyecto",
    description="Actualiza nombre, cliente y descripción de un proyecto propio. PB-01 — CA-2.",
)
def actualizar_proyecto(
    proyecto_id: int,
    body: ProyectoIn,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> ProyectoTecnicoOut:
    repo = ProyectoRepository(db)
    proyecto = repo.obtener_por_id(proyecto_id=proyecto_id, tecnico_id=current_user.id)
    if proyecto is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Proyecto no encontrado.",
        )
    proyecto = repo.actualizar(
        proyecto=proyecto,
        nombre=body.nombre,
        cliente_id=body.cliente_id,
        descripcion=body.descripcion,
    )
    return ProyectoTecnicoOut.from_proyecto(proyecto)


@router.patch(
    "/{proyecto_id}/archivar",
    response_model=ProyectoTecnicoOut,
    summary="Archivar proyecto",
    description="Cambia el estado del proyecto a 'archivado'. PB-01 — CA-3.",
)
def archivar_proyecto(
    proyecto_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> ProyectoTecnicoOut:
    repo = ProyectoRepository(db)
    proyecto = repo.obtener_por_id(proyecto_id=proyecto_id, tecnico_id=current_user.id)
    if proyecto is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Proyecto no encontrado.",
        )
    proyecto = repo.archivar(proyecto=proyecto)
    return ProyectoTecnicoOut.from_proyecto(proyecto)


@router.delete(
    "/{proyecto_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar proyecto",
    description="Elimina permanentemente el proyecto y todos sus datos. PB-01 — CA-4.",
)
def eliminar_proyecto(
    proyecto_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> None:
    repo = ProyectoRepository(db)
    proyecto = repo.obtener_por_id(proyecto_id=proyecto_id, tecnico_id=current_user.id)
    if proyecto is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Proyecto no encontrado.",
        )
    repo.eliminar(proyecto=proyecto)


@router.post(
    "/{proyecto_id}/plano",
    response_model=PlanoOut,
    status_code=status.HTTP_201_CREATED,
    summary="Subir o reemplazar plano principal",
    description=(
        "Sube el plano principal del proyecto autenticado. "
        "Si ya existe uno, lo reemplaza. PB-02."
    ),
)
def subir_plano_proyecto(
    proyecto_id: int,
    archivo: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> PlanoOut:
    repo = ProyectoRepository(db)
    proyecto = _obtener_proyecto_propio_o_error(
        repo=repo,
        proyecto_id=proyecto_id,
        tecnico_id=current_user.id,
    )

    storage = PlanoStorageService()
    try:
        stored = storage.save(proyecto_id=proyecto.id, upload=archivo)
    except PlanoValidationError as exc:
        detail = str(exc)
        error_status = (
            status.HTTP_413_REQUEST_ENTITY_TOO_LARGE
            if "excede el tamaño máximo" in detail
            else status.HTTP_415_UNSUPPORTED_MEDIA_TYPE
        )
        raise HTTPException(status_code=error_status, detail=detail)

    plano_previo_path = proyecto.plano.ruta_archivo if proyecto.plano else None
    try:
        if proyecto.plano is None:
            plano = Plano(
                proyecto_id=proyecto.id,
                nombre_archivo=stored.original_filename,
                ruta_archivo=stored.relative_path,
                mime_type=stored.mime_type,
                size_bytes=stored.size_bytes,
                uploaded_by=current_user.id,
            )
            db.add(plano)
        else:
            plano = proyecto.plano
            plano.nombre_archivo = stored.original_filename
            plano.ruta_archivo = stored.relative_path
            plano.mime_type = stored.mime_type
            plano.size_bytes = stored.size_bytes
            plano.uploaded_by = current_user.id
            plano.created_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(plano)
    except Exception:
        db.rollback()
        storage.delete(stored.relative_path)
        raise

    if plano_previo_path and plano_previo_path != stored.relative_path:
        storage.delete(plano_previo_path)

    return PlanoOut.model_validate(plano)


@router.get(
    "/{proyecto_id}/plano",
    response_model=PlanoOut,
    summary="Obtener metadata del plano principal",
    description="Retorna la metadata del plano principal del proyecto autenticado. PB-02.",
)
def obtener_plano_proyecto(
    proyecto_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> PlanoOut:
    repo = ProyectoRepository(db)
    proyecto = _obtener_proyecto_propio_o_error(
        repo=repo,
        proyecto_id=proyecto_id,
        tecnico_id=current_user.id,
    )
    if proyecto.plano is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plano no encontrado.",
        )
    return PlanoOut.model_validate(proyecto.plano)


@router.get(
    "/{proyecto_id}/plano/download",
    summary="Descargar plano principal",
    description="Descarga el archivo del plano principal del proyecto autenticado. PB-02.",
)
def descargar_plano_proyecto(
    proyecto_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> FileResponse:
    repo = ProyectoRepository(db)
    proyecto = _obtener_proyecto_propio_o_error(
        repo=repo,
        proyecto_id=proyecto_id,
        tecnico_id=current_user.id,
    )
    if proyecto.plano is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plano no encontrado.",
        )

    storage = PlanoStorageService()
    try:
        path = storage.resolve(proyecto.plano.ruta_archivo)
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plano no encontrado.",
        )

    if not path.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plano no encontrado.",
        )

    return FileResponse(
        path=path,
        media_type=proyecto.plano.mime_type,
        filename=proyecto.plano.nombre_archivo,
    )


@router.post(
    "/{proyecto_id}/wifi-scans",
    response_model=WifiScanLoteOut,
    status_code=status.HTTP_201_CREATED,
    summary="Recibir lote de señales WiFi",
    description=(
        "Recibe un lote de señales WiFi capturadas por mobile para un proyecto propio. "
        "PB-03."
    ),
)
def crear_wifi_scan(
    proyecto_id: int,
    body: WifiScanLoteIn,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> WifiScanLoteOut:
    proyecto_repo = ProyectoRepository(db)
    proyecto = _obtener_proyecto_propio_o_error(
        repo=proyecto_repo,
        proyecto_id=proyecto_id,
        tecnico_id=current_user.id,
    )
    if proyecto.plano is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El proyecto debe tener un plano cargado.",
        )
    if body.plano_id != proyecto.plano.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El plano indicado no pertenece al proyecto.",
        )

    punto_repo = PuntoMedicionRepository(db)
    punto_id_legacy, punto_medicion = _resolver_punto_wifi_scan(
        repo=punto_repo,
        proyecto_id=proyecto.id,
        plano_id=body.plano_id,
        punto_id_raw=body.punto_id,
    )

    repo = WifiScanRepository(db)
    lote = repo.crear_lote(
        proyecto_id=proyecto.id,
        tecnico_id=current_user.id,
        body=body,
        punto_medicion=punto_medicion,
        punto_id_legacy=punto_id_legacy,
    )
    return WifiScanLoteOut(
        id=lote.id,
        proyecto_id=lote.proyecto_id,
        plano_id=lote.plano_id,
        punto_id=lote.punto_id,
        capturado_en=lote.capturado_en,
        tecnico_id=lote.tecnico_id,
        origen=lote.origen,
        cantidad_senales=len(lote.senales),
        created_at=lote.created_at,
    )


@router.post(
    "/{proyecto_id}/puntos-medicion",
    response_model=PuntoMedicionOut,
    status_code=status.HTTP_201_CREATED,
    summary="Crear punto de medicion",
    description="Crea un punto de medicion sobre el plano del proyecto propio. PB-04.",
)
def crear_punto_medicion(
    proyecto_id: int,
    body: PuntoMedicionIn,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> PuntoMedicionOut:
    proyecto_repo = ProyectoRepository(db)
    proyecto = _obtener_proyecto_propio_o_error(
        repo=proyecto_repo,
        proyecto_id=proyecto_id,
        tecnico_id=current_user.id,
    )
    if proyecto.plano is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El proyecto debe tener un plano cargado.",
        )
    if body.plano_id != proyecto.plano.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El plano indicado no pertenece al proyecto.",
        )

    repo = PuntoMedicionRepository(db)
    punto = repo.crear(proyecto=proyecto, body=body)
    return PuntoMedicionOut.model_validate(punto)


@router.get(
    "/{proyecto_id}/puntos-medicion",
    response_model=list[PuntoMedicionOut],
    summary="Listar puntos de medicion",
    description="Lista los puntos de medicion del proyecto propio. PB-04.",
)
def listar_puntos_medicion(
    proyecto_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> list[PuntoMedicionOut]:
    proyecto_repo = ProyectoRepository(db)
    proyecto = _obtener_proyecto_propio_o_error(
        repo=proyecto_repo,
        proyecto_id=proyecto_id,
        tecnico_id=current_user.id,
    )
    if proyecto.plano is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El proyecto debe tener un plano cargado.",
        )

    repo = PuntoMedicionRepository(db)
    return [PuntoMedicionOut.model_validate(p) for p in repo.listar_por_proyecto(proyecto_id=proyecto.id)]


@router.put(
    "/{proyecto_id}/puntos-medicion/{punto_id}",
    response_model=PuntoMedicionOut,
    summary="Editar punto de medicion",
    description="Actualiza coordenadas y metadata de un punto de medicion propio. PB-04.",
)
def actualizar_punto_medicion(
    proyecto_id: int,
    punto_id: int,
    body: PuntoMedicionIn,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> PuntoMedicionOut:
    proyecto_repo = ProyectoRepository(db)
    proyecto = _obtener_proyecto_propio_o_error(
        repo=proyecto_repo,
        proyecto_id=proyecto_id,
        tecnico_id=current_user.id,
    )
    if proyecto.plano is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El proyecto debe tener un plano cargado.",
        )
    if body.plano_id != proyecto.plano.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El plano indicado no pertenece al proyecto.",
        )

    repo = PuntoMedicionRepository(db)
    punto = repo.obtener_por_id(proyecto_id=proyecto.id, punto_id=punto_id)
    if punto is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Punto de medición no encontrado.",
        )
    punto = repo.actualizar(punto=punto, body=body)
    return PuntoMedicionOut.model_validate(punto)


@router.delete(
    "/{proyecto_id}/puntos-medicion/{punto_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar punto de medicion",
    description="Elimina un punto de medicion propio. PB-04.",
)
def eliminar_punto_medicion(
    proyecto_id: int,
    punto_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> None:
    proyecto_repo = ProyectoRepository(db)
    proyecto = _obtener_proyecto_propio_o_error(
        repo=proyecto_repo,
        proyecto_id=proyecto_id,
        tecnico_id=current_user.id,
    )
    if proyecto.plano is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El proyecto debe tener un plano cargado.",
        )

    repo = PuntoMedicionRepository(db)
    punto = repo.obtener_por_id(proyecto_id=proyecto.id, punto_id=punto_id)
    if punto is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Punto de medición no encontrado.",
        )
    repo.eliminar(proyecto=proyecto, punto=punto)


@router.get(
    "/{proyecto_id}/heatmap",
    response_model=HeatmapOut,
    summary="Generar mapa de calor",
    description="Genera un heatmap JSON de cobertura WiFi sobre el plano del proyecto. PB-05.",
)
def obtener_heatmap(
    proyecto_id: int,
    plano_id: int | None = Query(default=None),
    ssid: str | None = Query(default=None),
    bssid: str | None = Query(default=None),
    resolution: int = Query(default=50, ge=10, le=200),
    metric: str = Query(default="best_rssi", pattern="^(best_rssi|avg_rssi)$"),
    format: str = Query(default="json", pattern="^json$"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> HeatmapOut:
    proyecto_repo = ProyectoRepository(db)
    proyecto = _obtener_proyecto_propio_para_consulta_o_error(
        repo=proyecto_repo,
        proyecto_id=proyecto_id,
        current_user=current_user,
    )
    if proyecto.plano is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El proyecto debe tener un plano cargado.",
        )

    plano_objetivo = proyecto.plano
    if plano_id is not None and plano_id != plano_objetivo.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El plano indicado no pertenece al proyecto.",
        )

    service = HeatmapService(db)
    try:
        return service.generate(
            proyecto_id=proyecto.id,
            plano_id=plano_objetivo.id,
            resolution=resolution,
            metric=metric,
            ssid=ssid,
            bssid=bssid,
        )
    except HeatmapError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        )


@router.get(
    "/{proyecto_id}/coverage-analysis",
    response_model=CoverageAnalysisOut,
    summary="Analizar cobertura WiFi",
    description=(
        "Genera un diagnóstico estructurado de cobertura WiFi sobre puntos reales del "
        "proyecto. PB-06."
    ),
)
def obtener_coverage_analysis(
    proyecto_id: int,
    plano_id: int | None = Query(default=None),
    ssid: str | None = Query(default=None),
    bssid: str | None = Query(default=None),
    metric: str = Query(default="best_rssi", pattern="^(best_rssi|avg_rssi)$"),
    include_heatmap_summary: bool = Query(default=False),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> CoverageAnalysisOut:
    proyecto_repo = ProyectoRepository(db)
    proyecto = _obtener_proyecto_propio_para_consulta_o_error(
        repo=proyecto_repo,
        proyecto_id=proyecto_id,
        current_user=current_user,
    )
    if proyecto.plano is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El proyecto debe tener un plano cargado.",
        )

    plano_objetivo = proyecto.plano
    if plano_id is not None and plano_id != plano_objetivo.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El plano indicado no pertenece al proyecto.",
        )

    service = CoverageAnalysisService(db)
    try:
        return service.analyze(
            proyecto_id=proyecto.id,
            plano_id=plano_objetivo.id,
            metric=metric,
            ssid=ssid,
            bssid=bssid,
            include_heatmap_summary=include_heatmap_summary,
        )
    except CoverageAnalysisError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        )


@router.post(
    "/{proyecto_id}/ap-recommendations",
    response_model=APRecommendationOut,
    summary="Generar recomendaciones heurísticas de APs",
    description=(
        "Genera recomendaciones explicables de ubicación y canal para APs "
        "basadas en la cobertura observada. PB-07."
    ),
)
def generar_ap_recommendations(
    proyecto_id: int,
    body: APRecommendationIn,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> APRecommendationOut:
    proyecto_repo = ProyectoRepository(db)
    proyecto = _obtener_proyecto_propio_para_consulta_o_error(
        repo=proyecto_repo,
        proyecto_id=proyecto_id,
        current_user=current_user,
    )
    if proyecto.plano is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El proyecto debe tener un plano cargado.",
        )
    if body.plano_id != proyecto.plano.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El plano indicado no pertenece al proyecto.",
        )

    coverage_service = CoverageAnalysisService(db)
    recommendation_service = APRecommendationService(coverage_service)
    try:
        return recommendation_service.recommend(
            proyecto_id=proyecto.id,
            body=body,
        )
    except CoverageAnalysisError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        )


@router.post(
    "/{proyecto_id}/technical-report",
    summary="Exportar reporte técnico PDF",
    description=(
        "Genera un reporte técnico PDF descargable con resumen, heatmap, análisis "
        "de cobertura y plan AP propuesto. PB-08."
    ),
)
def exportar_technical_report(
    proyecto_id: int,
    body: TechnicalReportIn,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
) -> Response:
    proyecto_repo = ProyectoRepository(db)
    proyecto = _obtener_proyecto_propio_para_consulta_o_error(
        repo=proyecto_repo,
        proyecto_id=proyecto_id,
        current_user=current_user,
    )
    if proyecto.plano is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El proyecto debe tener un plano cargado.",
        )
    if body.plano_id != proyecto.plano.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El plano indicado no pertenece al proyecto.",
        )

    coverage_service = CoverageAnalysisService(db)
    report_service = TechnicalReportService(
        heatmap_service=HeatmapService(db),
        coverage_analysis_service=coverage_service,
        ap_recommendation_service=APRecommendationService(coverage_service),
    )
    try:
        pdf_bytes = report_service.generate(
            proyecto=proyecto,
            current_user=current_user,
            body=body,
        )
    except (CoverageAnalysisError, HeatmapError) as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        )

    filename = f"wireless-heatmapper-proyecto-{proyecto.id}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
