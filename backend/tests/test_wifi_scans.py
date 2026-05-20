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
def cliente_wifi(db_session) -> Cliente:
    cliente = Cliente(nombre="Cliente WiFi")
    db_session.add(cliente)
    db_session.commit()
    db_session.refresh(cliente)
    return cliente


@pytest.fixture
def proyecto_con_plano(db_session, tecnico_usuario: Usuario, cliente_wifi: Cliente) -> tuple[Proyecto, Plano]:
    proyecto = Proyecto(
        nombre="Proyecto WiFi",
        cliente_id=cliente_wifi.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)

    plano = Plano(
        proyecto_id=proyecto.id,
        nombre_archivo="plano.pdf",
        ruta_archivo="proyecto_wifi/plano.pdf",
        mime_type="application/pdf",
        size_bytes=100,
        uploaded_by=tecnico_usuario.id,
    )
    db_session.add(plano)
    db_session.commit()
    db_session.refresh(plano)
    return proyecto, plano


@pytest.fixture
def proyecto_sin_plano(db_session, tecnico_usuario: Usuario, cliente_wifi: Cliente) -> Proyecto:
    proyecto = Proyecto(
        nombre="Proyecto sin plano",
        cliente_id=cliente_wifi.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)
    return proyecto


@pytest.fixture
def otro_tecnico_wifi(db_session) -> Usuario:
    usuario = Usuario(
        nombre="Otro Tecnico WiFi",
        email="otro.wifi@test.bo",
        password_hash="hash-no-importa",
        rol="tecnico",
        activo=True,
    )
    db_session.add(usuario)
    db_session.commit()
    db_session.refresh(usuario)
    return usuario


@pytest.fixture
def proyecto_ajeno_con_plano(
    db_session,
    otro_tecnico_wifi: Usuario,
    cliente_wifi: Cliente,
) -> tuple[Proyecto, Plano]:
    proyecto = Proyecto(
        nombre="Proyecto ajeno wifi",
        cliente_id=cliente_wifi.id,
        estado="en_progreso",
        tecnico_id=otro_tecnico_wifi.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)

    plano = Plano(
        proyecto_id=proyecto.id,
        nombre_archivo="ajeno.pdf",
        ruta_archivo="proyecto_ajeno/plano.pdf",
        mime_type="application/pdf",
        size_bytes=100,
        uploaded_by=otro_tecnico_wifi.id,
    )
    db_session.add(plano)
    db_session.commit()
    db_session.refresh(plano)
    return proyecto, plano


def payload_wifi(plano_id: int, *, total: int = 1) -> dict:
    senales = [
        {
            "ssid": f"Bulldog-{i}",
            "bssid": f"AA:BB:CC:DD:EE:{i:02X}",
            "rssi_dbm": -61,
            "frequency_mhz": 5180,
            "channel": 36,
            "security": "[WPA2-PSK-CCMP][ESS]",
        }
        for i in range(total)
    ]
    return {
        "plano_id": plano_id,
        "punto_id": None,
        "capturado_en": datetime(2026, 5, 19, 12, 34, 56, tzinfo=timezone.utc).isoformat(),
        "origen": "mobile",
        "app_version": "1.0.0",
        "device_id": "android-device-id",
        "senales": senales,
    }


@pytest.fixture
def punto_medicion_propio(
    db_session,
    proyecto_con_plano: tuple[Proyecto, Plano],
) -> PuntoMedicion:
    proyecto, plano = proyecto_con_plano
    punto = PuntoMedicion(
        proyecto_id=proyecto.id,
        plano_id=plano.id,
        x=0.42,
        y=0.67,
        modo="manual",
        etiqueta="Punto WiFi",
    )
    db_session.add(punto)
    proyecto.cantidad_puntos = 1
    db_session.commit()
    db_session.refresh(punto)
    return punto


@pytest.fixture
def punto_medicion_ajeno(
    db_session,
    proyecto_ajeno_con_plano: tuple[Proyecto, Plano],
) -> PuntoMedicion:
    proyecto, plano = proyecto_ajeno_con_plano
    punto = PuntoMedicion(
        proyecto_id=proyecto.id,
        plano_id=plano.id,
        x=0.2,
        y=0.3,
        modo="manual",
        etiqueta="Punto Ajeno",
    )
    db_session.add(punto)
    proyecto.cantidad_puntos = 1
    db_session.commit()
    db_session.refresh(punto)
    return punto


def test_crear_lote_valido_retorna_201(
    client: TestClient,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_con_plano
    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_wifi(plano.id),
    )

    assert response.status_code == 201
    data = response.json()
    assert data["proyecto_id"] == proyecto.id
    assert data["plano_id"] == plano.id
    assert data["tecnico_id"] > 0
    assert data["cantidad_senales"] == 1
    assert data["origen"] == "mobile"


def test_crear_lote_sin_token_retorna_401(
    client: TestClient,
    proyecto_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_con_plano
    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        json=payload_wifi(plano.id),
    )
    assert response.status_code == 401


def test_proyecto_ajeno_o_inexistente_retorna_404(
    client: TestClient,
    tecnico_token: str,
    proyecto_ajeno_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_ajeno_con_plano

    ajeno = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_wifi(plano.id),
    )
    inexistente = client.post(
        "/proyectos/999999/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_wifi(plano.id),
    )

    assert ajeno.status_code == 404
    assert inexistente.status_code == 404


def test_proyecto_archivado_retorna_409(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_con_plano
    proyecto.estado = "archivado"
    db_session.commit()

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_wifi(plano.id),
    )
    assert response.status_code == 409


def test_proyecto_sin_plano_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_sin_plano: Proyecto,
):
    response = client.post(
        f"/proyectos/{proyecto_sin_plano.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_wifi(999),
    )
    assert response.status_code == 409


def test_plano_id_ajeno_al_proyecto_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
    proyecto_ajeno_con_plano: tuple[Proyecto, Plano],
):
    proyecto, _ = proyecto_con_plano
    _, plano_ajeno = proyecto_ajeno_con_plano

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_wifi(plano_ajeno.id),
    )
    assert response.status_code == 409


def test_senales_vacio_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_con_plano
    body = payload_wifi(plano.id)
    body["senales"] = []

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=body,
    )
    assert response.status_code == 422


def test_mas_de_200_senales_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_con_plano
    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_wifi(plano.id, total=201),
    )
    assert response.status_code == 422


def test_rssi_fuera_de_rango_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_con_plano
    body = payload_wifi(plano.id)
    body["senales"][0]["rssi_dbm"] = -120

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=body,
    )
    assert response.status_code == 422


def test_bssid_invalido_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_con_plano
    body = payload_wifi(plano.id)
    body["senales"][0]["bssid"] = "INVALIDO"

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=body,
    )
    assert response.status_code == 422


def test_frequency_invalido_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_con_plano
    body = payload_wifi(plano.id)
    body["senales"][0]["frequency_mhz"] = 0

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=body,
    )
    assert response.status_code == 422


def test_persistencia_de_lote_y_senales(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_con_plano
    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_wifi(plano.id, total=2),
    )

    assert response.status_code == 201
    data = response.json()
    assert data["cantidad_senales"] == 2

    lote = db_session.query(WifiScanLote).filter(WifiScanLote.id == data["id"]).first()
    assert lote is not None
    assert lote.proyecto_id == proyecto.id
    assert lote.plano_id == plano.id
    assert lote.origen == "mobile"

    senales = db_session.query(WifiScanSenal).filter(WifiScanSenal.lote_id == lote.id).all()
    assert len(senales) == 2


def test_punto_id_null_sigue_funcionando(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_con_plano
    body = payload_wifi(plano.id)
    body["punto_id"] = None

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=body,
    )

    assert response.status_code == 201
    lote = db_session.query(WifiScanLote).filter(WifiScanLote.id == response.json()["id"]).first()
    assert lote is not None
    assert lote.punto_id is None
    assert lote.punto_medicion_id is None


def test_punto_id_string_sigue_funcionando_y_resuelve_fk(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
    punto_medicion_propio: PuntoMedicion,
):
    proyecto, plano = proyecto_con_plano
    body = payload_wifi(plano.id)
    body["punto_id"] = str(punto_medicion_propio.id)

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=body,
    )

    assert response.status_code == 201
    lote = db_session.query(WifiScanLote).filter(WifiScanLote.id == response.json()["id"]).first()
    assert lote is not None
    assert lote.punto_id == str(punto_medicion_propio.id)
    assert lote.punto_medicion_id == punto_medicion_propio.id


def test_punto_id_integer_funciona_y_se_persiste_legacy_string(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
    punto_medicion_propio: PuntoMedicion,
):
    proyecto, plano = proyecto_con_plano
    body = payload_wifi(plano.id)
    body["punto_id"] = punto_medicion_propio.id

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=body,
    )

    assert response.status_code == 201
    lote = db_session.query(WifiScanLote).filter(WifiScanLote.id == response.json()["id"]).first()
    assert lote is not None
    assert lote.punto_id == str(punto_medicion_propio.id)
    assert lote.punto_medicion_id == punto_medicion_propio.id


def test_punto_id_string_no_numerico_legacy_sigue_funcionando(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_con_plano
    body = payload_wifi(plano.id)
    body["punto_id"] = "p-legacy-001"

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=body,
    )

    assert response.status_code == 201
    lote = db_session.query(WifiScanLote).filter(WifiScanLote.id == response.json()["id"]).first()
    assert lote is not None
    assert lote.punto_id == "p-legacy-001"
    assert lote.punto_medicion_id is None


def test_punto_id_inexistente_devuelve_404(
    client: TestClient,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_con_plano
    body = payload_wifi(plano.id)
    body["punto_id"] = 999999

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=body,
    )

    assert response.status_code == 404


def test_punto_id_de_otro_proyecto_devuelve_404(
    client: TestClient,
    tecnico_token: str,
    proyecto_con_plano: tuple[Proyecto, Plano],
    punto_medicion_ajeno: PuntoMedicion,
):
    proyecto, plano = proyecto_con_plano
    body = payload_wifi(plano.id)
    body["punto_id"] = punto_medicion_ajeno.id

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=body,
    )

    assert response.status_code == 404
