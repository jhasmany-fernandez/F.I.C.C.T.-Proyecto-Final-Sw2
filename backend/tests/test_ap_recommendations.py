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
def cliente_ap(db_session) -> Cliente:
    cliente = Cliente(nombre="Cliente AP")
    db_session.add(cliente)
    db_session.commit()
    db_session.refresh(cliente)
    return cliente


@pytest.fixture
def proyecto_ap(db_session, tecnico_usuario: Usuario, cliente_ap: Cliente) -> Proyecto:
    proyecto = Proyecto(
        nombre="Proyecto AP",
        cliente_id=cliente_ap.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)
    return proyecto


@pytest.fixture
def plano_ap(db_session, proyecto_ap: Proyecto, tecnico_usuario: Usuario) -> Plano:
    plano = Plano(
        proyecto_id=proyecto_ap.id,
        nombre_archivo="ap.pdf",
        ruta_archivo="proyecto_ap/ap.pdf",
        mime_type="application/pdf",
        size_bytes=200,
        uploaded_by=tecnico_usuario.id,
    )
    db_session.add(plano)
    db_session.commit()
    db_session.refresh(plano)
    return plano


@pytest.fixture
def proyecto_ap_sin_plano(
    db_session,
    tecnico_usuario: Usuario,
    cliente_ap: Cliente,
) -> Proyecto:
    proyecto = Proyecto(
        nombre="Proyecto AP Sin Plano",
        cliente_id=cliente_ap.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)
    return proyecto


@pytest.fixture
def otro_tecnico_ap(db_session) -> Usuario:
    usuario = Usuario(
        nombre="Otro Tecnico AP",
        email="otro.ap@test.bo",
        password_hash="hash-no-importa",
        rol="tecnico",
        activo=True,
    )
    db_session.add(usuario)
    db_session.commit()
    db_session.refresh(usuario)
    return usuario


@pytest.fixture
def proyecto_ap_ajeno(
    db_session,
    otro_tecnico_ap: Usuario,
    cliente_ap: Cliente,
) -> tuple[Proyecto, Plano]:
    proyecto = Proyecto(
        nombre="Proyecto AP Ajeno",
        cliente_id=cliente_ap.id,
        estado="en_progreso",
        tecnico_id=otro_tecnico_ap.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)

    plano = Plano(
        proyecto_id=proyecto.id,
        nombre_archivo="ap-ajeno.pdf",
        ruta_archivo="proyecto_ap_ajeno/ap.pdf",
        mime_type="application/pdf",
        size_bytes=110,
        uploaded_by=otro_tecnico_ap.id,
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
        "target_rssi_dbm": -70,
        "max_recommendations": 3,
        "strategy": "coverage_gap",
        "band_preference": "auto",
        "include_channel_plan": True,
    }
    body.update(overrides)
    return body


def test_proyecto_ajeno_retorna_404(
    client: TestClient,
    tecnico_token: str,
    proyecto_ap_ajeno: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_ap_ajeno
    response = client.post(
        f"/proyectos/{proyecto.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano.id),
    )
    assert response.status_code == 404


def test_admin_puede_generar_recomendacion(
    client: TestClient,
    db_session,
    admin_token: str,
    tecnico_usuario: Usuario,
    proyecto_ap: Proyecto,
    plano_ap: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_ap, plano=plano_ap, x=0.3, y=0.6)
    _crear_scan(
        db_session,
        proyecto=proyecto_ap,
        plano=plano_ap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[{"ssid": "Weak", "bssid": "AA:AA:AA:AA:AA:01", "rssi_dbm": -80, "frequency_mhz": 5180, "channel": 36}],
    )

    response = client.post(
        f"/proyectos/{proyecto_ap.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {admin_token}"},
        json=_body(plano_ap.id),
    )
    assert response.status_code == 200
    assert response.json()["proyecto_id"] == proyecto_ap.id


def test_sin_plano_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_ap_sin_plano: Proyecto,
):
    response = client.post(
        f"/proyectos/{proyecto_ap_sin_plano.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(999),
    )
    assert response.status_code == 409


def test_sin_puntos_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_ap: Proyecto,
    plano_ap: Plano,
):
    response = client.post(
        f"/proyectos/{proyecto_ap.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_ap.id),
    )
    assert response.status_code == 409


def test_sin_mediciones_retorna_409(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_ap: Proyecto,
    plano_ap: Plano,
):
    _crear_punto(db_session, proyecto=proyecto_ap, plano=plano_ap, x=0.2, y=0.2)
    response = client.post(
        f"/proyectos/{proyecto_ap.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_ap.id),
    )
    assert response.status_code == 409


def test_target_rssi_invalido_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_ap: Proyecto,
    plano_ap: Plano,
):
    response = client.post(
        f"/proyectos/{proyecto_ap.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_ap.id, target_rssi_dbm=-95),
    )
    assert response.status_code == 422


def test_max_recommendations_invalido_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_ap: Proyecto,
    plano_ap: Plano,
):
    response = client.post(
        f"/proyectos/{proyecto_ap.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_ap.id, max_recommendations=0),
    )
    assert response.status_code == 422


def test_sin_zonas_debiles_devuelve_recommendations_vacio_con_warning(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_ap: Proyecto,
    plano_ap: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_ap, plano=plano_ap, x=0.4, y=0.4)
    _crear_scan(
        db_session,
        proyecto=proyecto_ap,
        plano=plano_ap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[{"ssid": "OK", "bssid": "AA:AA:AA:AA:AA:02", "rssi_dbm": -60, "frequency_mhz": 5180, "channel": 36}],
    )

    response = client.post(
        f"/proyectos/{proyecto_ap.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_ap.id),
    )

    assert response.status_code == 200
    data = response.json()
    assert data["recommendations"] == []
    assert "La cobertura cumple el objetivo definido." in data["warnings"]


def test_con_zona_debil_genera_recomendacion(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_ap: Proyecto,
    plano_ap: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_ap, plano=plano_ap, x=0.31, y=0.62)
    _crear_scan(
        db_session,
        proyecto=proyecto_ap,
        plano=plano_ap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[{"ssid": "Weak", "bssid": "AA:AA:AA:AA:AA:03", "rssi_dbm": -78, "frequency_mhz": 5180, "channel": 36}],
    )

    response = client.post(
        f"/proyectos/{proyecto_ap.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_ap.id),
    )

    assert response.status_code == 200
    rec = response.json()["recommendations"][0]
    assert "weak_zone" in rec["covers_findings"]
    assert 0 <= rec["confidence"] <= 1
    assert 0 <= rec["x"] <= 1
    assert 0 <= rec["y"] <= 1


def test_con_zona_muerta_genera_recomendacion(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_ap: Proyecto,
    plano_ap: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_ap, plano=plano_ap, x=0.12, y=0.18)
    _crear_scan(
        db_session,
        proyecto=proyecto_ap,
        plano=plano_ap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[{"ssid": "Dead", "bssid": "AA:AA:AA:AA:AA:04", "rssi_dbm": -95, "frequency_mhz": 2412, "channel": 1}],
    )

    response = client.post(
        f"/proyectos/{proyecto_ap.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_ap.id),
    )

    assert response.status_code == 200
    rec = response.json()["recommendations"][0]
    assert "dead_zone" in rec["covers_findings"]


def test_canal_sugerido_evita_conflicto_conocido(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_ap: Proyecto,
    plano_ap: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_ap, plano=plano_ap, x=0.2, y=0.7)
    _crear_scan(
        db_session,
        proyecto=proyecto_ap,
        plano=plano_ap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[
            {"ssid": "Weak", "bssid": "AA:BB:CC:DD:EE:01", "rssi_dbm": -79, "frequency_mhz": 2437, "channel": 6},
            {"ssid": "Weak", "bssid": "AA:BB:CC:DD:EE:02", "rssi_dbm": -78, "frequency_mhz": 2437, "channel": 6},
        ],
    )

    response = client.post(
        f"/proyectos/{proyecto_ap.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_ap.id, band_preference="2.4GHz"),
    )

    assert response.status_code == 200
    rec = response.json()["recommendations"][0]
    assert rec["channel"] in [1, 11]


def test_band_preference_24ghz_usa_canales_validos(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_ap: Proyecto,
    plano_ap: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_ap, plano=plano_ap, x=0.21, y=0.33)
    _crear_scan(
        db_session,
        proyecto=proyecto_ap,
        plano=plano_ap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[{"ssid": "Weak", "bssid": "AA:AA:AA:AA:AA:05", "rssi_dbm": -75, "frequency_mhz": 2412, "channel": 1}],
    )

    response = client.post(
        f"/proyectos/{proyecto_ap.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_ap.id, band_preference="2.4GHz"),
    )

    rec = response.json()["recommendations"][0]
    assert rec["band"] == "2.4GHz"
    assert rec["channel"] in [1, 6, 11]


def test_band_preference_5ghz_usa_canal_5ghz(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_ap: Proyecto,
    plano_ap: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_ap, plano=plano_ap, x=0.74, y=0.28)
    _crear_scan(
        db_session,
        proyecto=proyecto_ap,
        plano=plano_ap,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[{"ssid": "Weak5", "bssid": "AA:AA:AA:AA:AA:06", "rssi_dbm": -77, "frequency_mhz": 5180, "channel": 36}],
    )

    response = client.post(
        f"/proyectos/{proyecto_ap.id}/ap-recommendations",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=_body(plano_ap.id, band_preference="5GHz"),
    )

    rec = response.json()["recommendations"][0]
    assert rec["band"] == "5GHz"
    assert rec["channel"] in [36, 40, 44, 48]
