from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app.models.cliente import Cliente
from app.models.plano import Plano
from app.models.proyecto import Proyecto
from app.models.punto_medicion import PuntoMedicion
from app.models.usuario import Usuario
from app.models.wifi_scan import WifiScanLote, WifiScanSenal


@pytest.fixture
def cliente_report(db_session) -> Cliente:
    cliente = Cliente(nombre="Cliente Reporte")
    db_session.add(cliente)
    db_session.commit()
    db_session.refresh(cliente)
    return cliente


@pytest.fixture
def proyecto_report(db_session, tecnico_usuario: Usuario, cliente_report: Cliente) -> Proyecto:
    proyecto = Proyecto(
        nombre="Proyecto Reporte",
        cliente_id=cliente_report.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)
    return proyecto


@pytest.fixture
def plano_report(db_session, proyecto_report: Proyecto, tecnico_usuario: Usuario) -> Plano:
    plano = Plano(
        proyecto_id=proyecto_report.id,
        nombre_archivo="reporte.pdf",
        ruta_archivo="proyecto_reporte/reporte.pdf",
        mime_type="application/pdf",
        size_bytes=210,
        uploaded_by=tecnico_usuario.id,
    )
    db_session.add(plano)
    db_session.commit()
    db_session.refresh(plano)
    return plano


@pytest.fixture
def proyecto_report_sin_plano(
    db_session,
    tecnico_usuario: Usuario,
    cliente_report: Cliente,
) -> Proyecto:
    proyecto = Proyecto(
        nombre="Proyecto Reporte Sin Plano",
        cliente_id=cliente_report.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)
    return proyecto


@pytest.fixture
def otro_tecnico_report(db_session) -> Usuario:
    usuario = Usuario(
        nombre="Otro Tecnico Reporte",
        email="otro.reporte@test.bo",
        password_hash="hash-no-importa",
        rol="tecnico",
        activo=True,
    )
    db_session.add(usuario)
    db_session.commit()
    db_session.refresh(usuario)
    return usuario


@pytest.fixture
def proyecto_report_ajeno(
    db_session,
    otro_tecnico_report: Usuario,
    cliente_report: Cliente,
) -> tuple[Proyecto, Plano]:
    proyecto = Proyecto(
        nombre="Proyecto Reporte Ajeno",
        cliente_id=cliente_report.id,
        estado="en_progreso",
        tecnico_id=otro_tecnico_report.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)

    plano = Plano(
        proyecto_id=proyecto.id,
        nombre_archivo="reporte-ajeno.pdf",
        ruta_archivo="proyecto_reporte_ajeno/reporte.pdf",
        mime_type="application/pdf",
        size_bytes=110,
        uploaded_by=otro_tecnico_report.id,
    )
    db_session.add(plano)
    db_session.commit()
    db_session.refresh(plano)
    return proyecto, plano


def _crear_punto(
    db_session,
    *,
    proyecto: Proyecto,
    plano: Plano,
    x: float,
    y: float,
) -> PuntoMedicion:
    punto = PuntoMedicion(
        proyecto_id=proyecto.id,
        plano_id=plano.id,
        x=x,
        y=y,
        modo="manual",
    )
    db_session.add(punto)
    proyecto.cantidad_puntos = (proyecto.cantidad_puntos or 0) + 1
    db_session.commit()
    db_session.refresh(punto)
    return punto


def _crear_scan(
    db_session,
    *,
    proyecto: Proyecto,
    plano: Plano,
    tecnico_id: int,
    punto: PuntoMedicion | None,
    punto_id_legacy: str | None = None,
    senales: list[dict] | None = None,
) -> WifiScanLote:
    lote = WifiScanLote(
        proyecto_id=proyecto.id,
        plano_id=plano.id,
        tecnico_id=tecnico_id,
        punto_medicion_id=punto.id if punto else None,
        punto_id=punto_id_legacy,
        capturado_en=datetime(2026, 5, 19, 12, 34, 56, tzinfo=timezone.utc),
        origen="mobile",
        app_version="1.0.0+1",
    )
    lote.senales = [
        WifiScanSenal(
            ssid=signal.get("ssid"),
            bssid=signal["bssid"],
            rssi_dbm=signal["rssi_dbm"],
            frequency_mhz=signal.get("frequency_mhz"),
            channel=signal.get("channel"),
            security=signal.get("security"),
        )
        for signal in (senales or [])
    ]
    db_session.add(lote)
    db_session.commit()
    db_session.refresh(lote)
    return lote


def _body(plano_id: int, **overrides) -> dict:
    body = {
        "plano_id": plano_id,
        "include_heatmap": True,
        "include_coverage_analysis": True,
        "include_ap_recommendations": True,
        "metric": "best_rssi",
        "target_rssi_dbm": -70,
        "format": "pdf",
    }
    body.update(overrides)
    return body


def _crear_dataset_minimo(
    db_session,
    *,
    proyecto: Proyecto,
    plano: Plano,
    tecnico_id: int,
    rssi: int = -78,
) -> PuntoMedicion:
    punto = _crear_punto(db_session, proyecto=proyecto, plano=plano, x=0.35, y=0.62)
    _crear_scan(
        db_session,
        proyecto=proyecto,
        plano=plano,
        tecnico_id=tecnico_id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[{"ssid": "Weak", "bssid": "AA:AA:AA:AA:AA:11", "rssi_dbm": rssi, "frequency_mhz": 5180, "channel": 36}],
    )
    return punto


def test_tecnico_dueno_genera_pdf_200(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_report: Proyecto,
    plano_report: Plano,
):
    _crear_dataset_minimo(
        db_session,
        proyecto=proyecto_report,
        plano=plano_report,
        tecnico_id=tecnico_usuario.id,
    )

    response = client.post(
        f"/proyectos/{proyecto_report.id}/technical-report",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_report.id),
    )

    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert "attachment; filename=" in response.headers["content-disposition"]
    assert response.content.startswith(b"%PDF")


def test_admin_genera_pdf_200(
    client: TestClient,
    db_session,
    admin_token: str,
    tecnico_usuario: Usuario,
    proyecto_report: Proyecto,
    plano_report: Plano,
):
    _crear_dataset_minimo(
        db_session,
        proyecto=proyecto_report,
        plano=plano_report,
        tecnico_id=tecnico_usuario.id,
    )

    response = client.post(
        f"/proyectos/{proyecto_report.id}/technical-report",
        headers={"Authorization": f"Bearer {admin_token}"},
        json=_body(plano_report.id),
    )

    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content.startswith(b"%PDF")


def test_pdf_contiene_texto_clave(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_report: Proyecto,
    plano_report: Plano,
):
    _crear_dataset_minimo(
        db_session,
        proyecto=proyecto_report,
        plano=plano_report,
        tecnico_id=tecnico_usuario.id,
    )

    response = client.post(
        f"/proyectos/{proyecto_report.id}/technical-report",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_report.id),
    )

    assert b"Wireless HeatMapper" in response.content
    assert b"Resumen ejecutivo" in response.content
    assert b"Analisis de cobertura" in response.content
    assert b"Recomendaciones de APs" in response.content


def test_tecnico_ajeno_retorna_404(
    client: TestClient,
    tecnico_token: str,
    proyecto_report_ajeno: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_report_ajeno
    response = client.post(
        f"/proyectos/{proyecto.id}/technical-report",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano.id),
    )
    assert response.status_code == 404


def test_sin_plano_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_report_sin_plano: Proyecto,
):
    response = client.post(
        f"/proyectos/{proyecto_report_sin_plano.id}/technical-report",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(999),
    )
    assert response.status_code == 409


def test_sin_puntos_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_report: Proyecto,
    plano_report: Plano,
):
    response = client.post(
        f"/proyectos/{proyecto_report.id}/technical-report",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_report.id),
    )
    assert response.status_code == 409


def test_sin_mediciones_retorna_409(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_report: Proyecto,
    plano_report: Plano,
):
    _crear_punto(db_session, proyecto=proyecto_report, plano=plano_report, x=0.2, y=0.2)
    response = client.post(
        f"/proyectos/{proyecto_report.id}/technical-report",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_report.id),
    )
    assert response.status_code == 409


def test_plano_incorrecto_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_report: Proyecto,
):
    response = client.post(
        f"/proyectos/{proyecto_report.id}/technical-report",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(999),
    )
    assert response.status_code == 409


def test_format_invalido_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_report: Proyecto,
    plano_report: Plano,
):
    response = client.post(
        f"/proyectos/{proyecto_report.id}/technical-report",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_report.id, format="html"),
    )
    assert response.status_code == 422


def test_metric_invalido_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_report: Proyecto,
    plano_report: Plano,
):
    response = client.post(
        f"/proyectos/{proyecto_report.id}/technical-report",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_report.id, metric="median"),
    )
    assert response.status_code == 422
