from __future__ import annotations

from datetime import datetime, timezone
import re

import pytest
from fastapi.testclient import TestClient

from app.models.cliente import Cliente
from app.models.plano import Plano
from app.models.proyecto import Proyecto
from app.models.punto_medicion import PuntoMedicion
from app.models.usuario import Usuario
from app.models.wifi_scan import WifiScanLote, WifiScanSenal


@pytest.fixture
def cliente_heatmap(db_session) -> Cliente:
    cliente = Cliente(nombre="Cliente Heatmap")
    db_session.add(cliente)
    db_session.commit()
    db_session.refresh(cliente)
    return cliente


@pytest.fixture
def proyecto_heatmap(db_session, tecnico_usuario: Usuario, cliente_heatmap: Cliente) -> Proyecto:
    proyecto = Proyecto(
        nombre="Proyecto Heatmap",
        cliente_id=cliente_heatmap.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)
    return proyecto


@pytest.fixture
def plano_heatmap(db_session, proyecto_heatmap: Proyecto, tecnico_usuario: Usuario) -> Plano:
    plano = Plano(
        proyecto_id=proyecto_heatmap.id,
        nombre_archivo="heatmap.pdf",
        ruta_archivo="proyecto_heatmap/heatmap.pdf",
        mime_type="application/pdf",
        size_bytes=200,
        uploaded_by=tecnico_usuario.id,
    )
    db_session.add(plano)
    db_session.commit()
    db_session.refresh(plano)
    return plano


@pytest.fixture
def proyecto_heatmap_sin_plano(db_session, tecnico_usuario: Usuario, cliente_heatmap: Cliente) -> Proyecto:
    proyecto = Proyecto(
        nombre="Proyecto Heatmap Sin Plano",
        cliente_id=cliente_heatmap.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)
    return proyecto


def _crear_punto(
    db_session,
    *,
    proyecto: Proyecto,
    plano: Plano,
    x: float,
    y: float,
    modo: str = "manual",
) -> PuntoMedicion:
    punto = PuntoMedicion(
        proyecto_id=proyecto.id,
        plano_id=plano.id,
        x=x,
        y=y,
        modo=modo,
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
    punto_id_legacy: str | None,
    rssi: int,
    ssid: str = "Bulldog-5G",
    bssid: str = "AA:BB:CC:DD:EE:FF",
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
            ssid=ssid,
            bssid=bssid,
            rssi_dbm=rssi,
            frequency_mhz=5180,
            channel=36,
            security="[WPA2-PSK-CCMP][ESS]",
        )
    ]
    db_session.add(lote)
    db_session.commit()
    db_session.refresh(lote)
    return lote


def test_proyecto_sin_plano_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_heatmap_sin_plano: Proyecto,
):
    response = client.get(
        f"/proyectos/{proyecto_heatmap_sin_plano.id}/heatmap",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 409


def test_proyecto_sin_puntos_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_heatmap: Proyecto,
    plano_heatmap: Plano,
):
    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?plano_id={plano_heatmap.id}",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 409


def test_proyecto_sin_scans_asociados_a_puntos_retorna_409(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_heatmap: Proyecto,
    plano_heatmap: Plano,
):
    _crear_punto(db_session, proyecto=proyecto_heatmap, plano=plano_heatmap, x=0.2, y=0.2)

    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?plano_id={plano_heatmap.id}",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 409


def test_resolution_menor_a_10_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_heatmap: Proyecto,
):
    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?resolution=9",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 422


def test_resolution_mayor_a_200_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_heatmap: Proyecto,
):
    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?resolution=201",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 422


def test_metric_invalido_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_heatmap: Proyecto,
):
    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?metric=invalid",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 422


def test_format_invalido_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_heatmap: Proyecto,
):
    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?format=png",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 422


def test_heatmap_con_1_punto_retorna_200_con_warning(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_heatmap: Proyecto,
    plano_heatmap: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_heatmap, plano=plano_heatmap, x=0.1, y=0.2)
    _crear_scan(
        db_session,
        proyecto=proyecto_heatmap,
        plano=plano_heatmap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        rssi=-60,
    )

    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?plano_id={plano_heatmap.id}&resolution=10",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["warning"] is not None
    assert data["points_used"] == 1
    assert len(data["grid"]) == 100


def test_admin_puede_consultar_heatmap_de_proyecto_existente(
    client: TestClient,
    db_session,
    admin_token: str,
    tecnico_usuario: Usuario,
    proyecto_heatmap: Proyecto,
    plano_heatmap: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_heatmap, plano=plano_heatmap, x=0.1, y=0.2)
    _crear_scan(
        db_session,
        proyecto=proyecto_heatmap,
        plano=plano_heatmap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        rssi=-60,
    )

    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?plano_id={plano_heatmap.id}&resolution=10",
        headers={"Authorization": f"Bearer {admin_token}"},
    )

    assert response.status_code == 200
    assert response.json()["proyecto_id"] == proyecto_heatmap.id


def test_heatmap_con_3_puntos_retorna_200_sin_warning(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_heatmap: Proyecto,
    plano_heatmap: Plano,
):
    puntos = [
        _crear_punto(db_session, proyecto=proyecto_heatmap, plano=plano_heatmap, x=0.1, y=0.2),
        _crear_punto(db_session, proyecto=proyecto_heatmap, plano=plano_heatmap, x=0.7, y=0.3),
        _crear_punto(db_session, proyecto=proyecto_heatmap, plano=plano_heatmap, x=0.4, y=0.8),
    ]
    rssis = [-60, -50, -70]
    for punto, rssi in zip(puntos, rssis):
        _crear_scan(
            db_session,
            proyecto=proyecto_heatmap,
            plano=plano_heatmap,
            tecnico_id=tecnico_usuario.id,
            punto=punto,
            punto_id_legacy=str(punto.id),
            rssi=rssi,
        )

    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?plano_id={plano_heatmap.id}&resolution=10",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["warning"] is None
    assert data["points_used"] == 3
    assert len(data["grid"]) == 100
    for cell in data["grid"]:
        assert 0 <= cell["normalized"] <= 1
        assert re.fullmatch(r"#[0-9A-F]{6}", cell["color"])


def test_filtro_por_ssid(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_heatmap: Proyecto,
    plano_heatmap: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_heatmap, plano=plano_heatmap, x=0.2, y=0.2)
    _crear_scan(
        db_session,
        proyecto=proyecto_heatmap,
        plano=plano_heatmap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        rssi=-55,
        ssid="Bulldog-5G",
    )
    _crear_scan(
        db_session,
        proyecto=proyecto_heatmap,
        plano=plano_heatmap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        rssi=-80,
        ssid="OtraRed",
    )

    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?plano_id={plano_heatmap.id}&ssid=Bulldog-5G&resolution=10",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["points_used"] == 1


def test_filtro_por_bssid(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_heatmap: Proyecto,
    plano_heatmap: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_heatmap, plano=plano_heatmap, x=0.2, y=0.2)
    _crear_scan(
        db_session,
        proyecto=proyecto_heatmap,
        plano=plano_heatmap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        rssi=-55,
        bssid="AA:BB:CC:DD:EE:FF",
    )
    _crear_scan(
        db_session,
        proyecto=proyecto_heatmap,
        plano=plano_heatmap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        rssi=-80,
        bssid="11:22:33:44:55:66",
    )

    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?plano_id={plano_heatmap.id}&bssid=AA:BB:CC:DD:EE:FF&resolution=10",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["points_used"] == 1


def test_fallback_legacy_punto_id_numerico(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_heatmap: Proyecto,
    plano_heatmap: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_heatmap, plano=plano_heatmap, x=0.3, y=0.3)
    _crear_scan(
        db_session,
        proyecto=proyecto_heatmap,
        plano=plano_heatmap,
        tecnico_id=tecnico_usuario.id,
        punto=None,
        punto_id_legacy=str(punto.id),
        rssi=-65,
    )

    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?plano_id={plano_heatmap.id}&resolution=10",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 200


def test_tiempo_razonable_resolution_50(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_heatmap: Proyecto,
    plano_heatmap: Plano,
):
    puntos = [
        _crear_punto(db_session, proyecto=proyecto_heatmap, plano=plano_heatmap, x=0.1, y=0.1),
        _crear_punto(db_session, proyecto=proyecto_heatmap, plano=plano_heatmap, x=0.8, y=0.2),
        _crear_punto(db_session, proyecto=proyecto_heatmap, plano=plano_heatmap, x=0.4, y=0.7),
    ]
    for punto, rssi in zip(puntos, [-60, -50, -70]):
        _crear_scan(
            db_session,
            proyecto=proyecto_heatmap,
            plano=plano_heatmap,
            tecnico_id=tecnico_usuario.id,
            punto=punto,
            punto_id_legacy=str(punto.id),
            rssi=rssi,
        )

    response = client.get(
        f"/proyectos/{proyecto_heatmap.id}/heatmap?plano_id={plano_heatmap.id}&resolution=50",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 200
    assert len(response.json()["grid"]) == 2500
