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
def cliente_coverage(db_session) -> Cliente:
    cliente = Cliente(nombre="Cliente Coverage")
    db_session.add(cliente)
    db_session.commit()
    db_session.refresh(cliente)
    return cliente


@pytest.fixture
def proyecto_coverage(db_session, tecnico_usuario: Usuario, cliente_coverage: Cliente) -> Proyecto:
    proyecto = Proyecto(
        nombre="Proyecto Coverage",
        cliente_id=cliente_coverage.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)
    return proyecto


@pytest.fixture
def plano_coverage(db_session, proyecto_coverage: Proyecto, tecnico_usuario: Usuario) -> Plano:
    plano = Plano(
        proyecto_id=proyecto_coverage.id,
        nombre_archivo="coverage.pdf",
        ruta_archivo="proyecto_coverage/coverage.pdf",
        mime_type="application/pdf",
        size_bytes=220,
        uploaded_by=tecnico_usuario.id,
    )
    db_session.add(plano)
    db_session.commit()
    db_session.refresh(plano)
    return plano


@pytest.fixture
def proyecto_coverage_sin_plano(
    db_session,
    tecnico_usuario: Usuario,
    cliente_coverage: Cliente,
) -> Proyecto:
    proyecto = Proyecto(
        nombre="Proyecto Coverage Sin Plano",
        cliente_id=cliente_coverage.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)
    return proyecto


@pytest.fixture
def otro_tecnico_coverage(db_session) -> Usuario:
    usuario = Usuario(
        nombre="Otro Tecnico Coverage",
        email="otro.coverage@test.bo",
        password_hash="hash-no-importa",
        rol="tecnico",
        activo=True,
    )
    db_session.add(usuario)
    db_session.commit()
    db_session.refresh(usuario)
    return usuario


@pytest.fixture
def proyecto_coverage_ajeno(
    db_session,
    otro_tecnico_coverage: Usuario,
    cliente_coverage: Cliente,
) -> tuple[Proyecto, Plano]:
    proyecto = Proyecto(
        nombre="Proyecto Coverage Ajeno",
        cliente_id=cliente_coverage.id,
        estado="en_progreso",
        tecnico_id=otro_tecnico_coverage.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)

    plano = Plano(
        proyecto_id=proyecto.id,
        nombre_archivo="coverage-ajeno.pdf",
        ruta_archivo="proyecto_coverage_ajeno/coverage.pdf",
        mime_type="application/pdf",
        size_bytes=120,
        uploaded_by=otro_tecnico_coverage.id,
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


def _url(proyecto_id: int, **params) -> str:
    base = f"/proyectos/{proyecto_id}/coverage-analysis"
    if not params:
        return base
    query = "&".join(f"{key}={value}" for key, value in params.items())
    return f"{base}?{query}"


def test_proyecto_ajeno_retorna_404(
    client: TestClient,
    tecnico_token: str,
    proyecto_coverage_ajeno: tuple[Proyecto, Plano],
):
    proyecto, _ = proyecto_coverage_ajeno
    response = client.get(
        _url(proyecto.id),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 404


def test_tecnico_dueno_puede_consultar_coverage_analysis(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_coverage: Proyecto,
    plano_coverage: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.4, y=0.4)
    _crear_scan(
        db_session,
        proyecto=proyecto_coverage,
        plano=plano_coverage,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[{"ssid": "Bulldog", "bssid": "AA:50:00:00:00:01", "rssi_dbm": -68, "frequency_mhz": 5180, "channel": 36}],
    )

    response = client.get(
        _url(proyecto_coverage.id, plano_id=plano_coverage.id),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    assert response.json()["proyecto_id"] == proyecto_coverage.id


def test_admin_puede_consultar_coverage_analysis_de_proyecto_existente(
    client: TestClient,
    db_session,
    admin_token: str,
    tecnico_usuario: Usuario,
    proyecto_coverage: Proyecto,
    plano_coverage: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.6, y=0.4)
    _crear_scan(
        db_session,
        proyecto=proyecto_coverage,
        plano=plano_coverage,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[{"ssid": "Bulldog", "bssid": "AA:60:00:00:00:01", "rssi_dbm": -64, "frequency_mhz": 5180, "channel": 36}],
    )

    response = client.get(
        _url(proyecto_coverage.id, plano_id=plano_coverage.id),
        headers={"Authorization": f"Bearer {admin_token}"},
    )

    assert response.status_code == 200
    assert response.json()["proyecto_id"] == proyecto_coverage.id


def test_admin_con_proyecto_inexistente_recibe_404(
    client: TestClient,
    admin_token: str,
):
    response = client.get(
        _url(999999),
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 404


def test_proyecto_sin_plano_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_coverage_sin_plano: Proyecto,
):
    response = client.get(
        _url(proyecto_coverage_sin_plano.id),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 409


def test_proyecto_sin_puntos_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_coverage: Proyecto,
    plano_coverage: Plano,
):
    response = client.get(
        _url(proyecto_coverage.id, plano_id=plano_coverage.id),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 409


def test_proyecto_sin_mediciones_retorna_409(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_coverage: Proyecto,
    plano_coverage: Plano,
):
    _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.2, y=0.2)

    response = client.get(
        _url(proyecto_coverage.id, plano_id=plano_coverage.id),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 409


def test_detecta_dead_weak_ok_y_calcula_porcentajes(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_coverage: Proyecto,
    plano_coverage: Plano,
):
    punto_dead = _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.1, y=0.1)
    punto_weak = _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.5, y=0.5)
    punto_ok = _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.9, y=0.9)

    _crear_scan(
        db_session,
        proyecto=proyecto_coverage,
        plano=plano_coverage,
        tecnico_id=tecnico_usuario.id,
        punto=punto_dead,
        punto_id_legacy=str(punto_dead.id),
        senales=[{"ssid": "Dead", "bssid": "AA:AA:AA:AA:AA:01", "rssi_dbm": -95, "frequency_mhz": 2412, "channel": 1}],
    )
    _crear_scan(
        db_session,
        proyecto=proyecto_coverage,
        plano=plano_coverage,
        tecnico_id=tecnico_usuario.id,
        punto=punto_weak,
        punto_id_legacy=str(punto_weak.id),
        senales=[{"ssid": "Weak", "bssid": "AA:AA:AA:AA:AA:02", "rssi_dbm": -80, "frequency_mhz": 2437, "channel": 6}],
    )
    _crear_scan(
        db_session,
        proyecto=proyecto_coverage,
        plano=plano_coverage,
        tecnico_id=tecnico_usuario.id,
        punto=punto_ok,
        punto_id_legacy=str(punto_ok.id),
        senales=[{"ssid": "Ok", "bssid": "AA:AA:AA:AA:AA:03", "rssi_dbm": -60, "frequency_mhz": 5180, "channel": 36}],
    )

    response = client.get(
        _url(proyecto_coverage.id, plano_id=plano_coverage.id),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["summary"]["points_analyzed"] == 3
    assert data["summary"]["dead_zones_count"] == 1
    assert data["summary"]["weak_zones_count"] == 1
    assert data["summary"]["coverage_ok_count"] == 1
    assert data["summary"]["coverage_ok_percent"] == 33.33
    assert data["summary"]["best_rssi_dbm"] == -60.0
    assert data["summary"]["worst_rssi_dbm"] == -95.0
    finding_types = {finding["type"] for finding in data["findings"]}
    assert "dead_zone" in finding_types
    assert "weak_zone" in finding_types


def test_detecta_cci_en_mismo_canal(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_coverage: Proyecto,
    plano_coverage: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.4, y=0.6)
    _crear_scan(
        db_session,
        proyecto=proyecto_coverage,
        plano=plano_coverage,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[
            {"ssid": "Bulldog-5G", "bssid": "AA:BB:CC:DD:EE:01", "rssi_dbm": -60, "frequency_mhz": 2437, "channel": 6},
            {"ssid": "Bulldog-5G", "bssid": "AA:BB:CC:DD:EE:02", "rssi_dbm": -65, "frequency_mhz": 2437, "channel": 6},
        ],
    )

    response = client.get(
        _url(proyecto_coverage.id, plano_id=plano_coverage.id),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    cci = response.json()["channel_analysis"]["cci"]
    assert len(cci) == 1
    assert cci[0]["channel"] == 6
    assert cci[0]["bssid_count"] == 2


def test_detecta_aci_en_canales_cercanos(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_coverage: Proyecto,
    plano_coverage: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.3, y=0.7)
    _crear_scan(
        db_session,
        proyecto=proyecto_coverage,
        plano=plano_coverage,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[
            {"ssid": "Bulldog-24", "bssid": "AA:BB:CC:DD:EF:01", "rssi_dbm": -60, "frequency_mhz": 2412, "channel": 1},
            {"ssid": "Bulldog-24", "bssid": "AA:BB:CC:DD:EF:02", "rssi_dbm": -62, "frequency_mhz": 2422, "channel": 3},
        ],
    )

    response = client.get(
        _url(proyecto_coverage.id, plano_id=plano_coverage.id),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    aci = response.json()["channel_analysis"]["aci"]
    assert len(aci) == 1
    assert aci[0]["channel"] == 1
    assert aci[0]["adjacent_to"] == 3


def test_detecta_overlap_por_multiples_bssid_fuertes(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_coverage: Proyecto,
    plano_coverage: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.25, y=0.75)
    _crear_scan(
        db_session,
        proyecto=proyecto_coverage,
        plano=plano_coverage,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[
            {"ssid": "Bulldog-5G", "bssid": "AA:00:00:00:00:01", "rssi_dbm": -60, "frequency_mhz": 5180, "channel": 36},
            {"ssid": "Bulldog-5G", "bssid": "AA:00:00:00:00:02", "rssi_dbm": -61, "frequency_mhz": 5200, "channel": 40},
        ],
    )

    response = client.get(
        _url(proyecto_coverage.id, plano_id=plano_coverage.id),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    overlap = [finding for finding in response.json()["findings"] if finding["type"] == "overlap"]
    assert len(overlap) == 1
    assert overlap[0]["punto_id"] == punto.id


def test_filtro_por_ssid(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_coverage: Proyecto,
    plano_coverage: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.11, y=0.22)
    _crear_scan(
        db_session,
        proyecto=proyecto_coverage,
        plano=plano_coverage,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[
            {"ssid": "Objetivo", "bssid": "AA:10:00:00:00:01", "rssi_dbm": -65, "frequency_mhz": 5180, "channel": 36},
            {"ssid": "Otra", "bssid": "AA:10:00:00:00:02", "rssi_dbm": -40, "frequency_mhz": 5200, "channel": 40},
        ],
    )

    response = client.get(
        _url(proyecto_coverage.id, plano_id=plano_coverage.id, ssid="Objetivo"),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    assert response.json()["summary"]["best_rssi_dbm"] == -65.0


def test_filtro_por_bssid(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_coverage: Proyecto,
    plano_coverage: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.33, y=0.44)
    _crear_scan(
        db_session,
        proyecto=proyecto_coverage,
        plano=plano_coverage,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[
            {"ssid": "Bulldog", "bssid": "AA:20:00:00:00:01", "rssi_dbm": -72, "frequency_mhz": 2412, "channel": 1},
            {"ssid": "Bulldog", "bssid": "AA:20:00:00:00:02", "rssi_dbm": -50, "frequency_mhz": 2417, "channel": 2},
        ],
    )

    response = client.get(
        _url(proyecto_coverage.id, plano_id=plano_coverage.id, bssid="AA:20:00:00:00:01"),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    assert response.json()["summary"]["best_rssi_dbm"] == -72.0


def test_proyecto_archivado_permite_consulta(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_coverage: Proyecto,
    plano_coverage: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.5, y=0.5)
    _crear_scan(
        db_session,
        proyecto=proyecto_coverage,
        plano=plano_coverage,
        tecnico_id=tecnico_usuario.id,
        punto=punto,
        punto_id_legacy=str(punto.id),
        senales=[{"ssid": "Bulldog", "bssid": "AA:30:00:00:00:01", "rssi_dbm": -68, "frequency_mhz": 5180, "channel": 36}],
    )
    proyecto_coverage.estado = "archivado"
    db_session.commit()

    response = client.get(
        _url(proyecto_coverage.id, plano_id=plano_coverage.id, include_heatmap_summary="true"),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    assert response.json()["heatmap_summary"]["points_used"] == 1


def test_fallback_legacy_por_punto_id_numerico(
    client: TestClient,
    db_session,
    tecnico_token: str,
    tecnico_usuario: Usuario,
    proyecto_coverage: Proyecto,
    plano_coverage: Plano,
):
    punto = _crear_punto(db_session, proyecto=proyecto_coverage, plano=plano_coverage, x=0.7, y=0.2)
    _crear_scan(
        db_session,
        proyecto=proyecto_coverage,
        plano=plano_coverage,
        tecnico_id=tecnico_usuario.id,
        punto=None,
        punto_id_legacy=str(punto.id),
        senales=[{"ssid": "Legacy", "bssid": "AA:40:00:00:00:01", "rssi_dbm": -66, "frequency_mhz": 5180, "channel": 36}],
    )

    response = client.get(
        _url(proyecto_coverage.id, plano_id=plano_coverage.id),
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    assert response.json()["summary"]["points_analyzed"] == 1
