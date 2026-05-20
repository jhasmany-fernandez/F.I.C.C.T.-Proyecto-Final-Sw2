from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app.models.cliente import Cliente
from app.models.plano import Plano
from app.models.proyecto import Proyecto
from app.models.punto_medicion import PuntoMedicion
from app.models.usuario import Usuario
from app.models.wifi_scan import WifiScanLote


@pytest.fixture
def cliente_puntos(db_session) -> Cliente:
    cliente = Cliente(nombre="Cliente Puntos")
    db_session.add(cliente)
    db_session.commit()
    db_session.refresh(cliente)
    return cliente


@pytest.fixture
def proyecto_puntos_con_plano(
    db_session,
    tecnico_usuario: Usuario,
    cliente_puntos: Cliente,
) -> tuple[Proyecto, Plano]:
    proyecto = Proyecto(
        nombre="Proyecto Puntos",
        cliente_id=cliente_puntos.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)

    plano = Plano(
        proyecto_id=proyecto.id,
        nombre_archivo="puntos.pdf",
        ruta_archivo="proyecto_puntos/puntos.pdf",
        mime_type="application/pdf",
        size_bytes=150,
        uploaded_by=tecnico_usuario.id,
    )
    db_session.add(plano)
    db_session.commit()
    db_session.refresh(plano)
    return proyecto, plano


@pytest.fixture
def proyecto_puntos_sin_plano(db_session, tecnico_usuario: Usuario, cliente_puntos: Cliente) -> Proyecto:
    proyecto = Proyecto(
        nombre="Proyecto Puntos Sin Plano",
        cliente_id=cliente_puntos.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)
    return proyecto


@pytest.fixture
def otro_tecnico_puntos(db_session) -> Usuario:
    usuario = Usuario(
        nombre="Otro Tecnico Puntos",
        email="otro.puntos@test.bo",
        password_hash="hash-no-importa",
        rol="tecnico",
        activo=True,
    )
    db_session.add(usuario)
    db_session.commit()
    db_session.refresh(usuario)
    return usuario


@pytest.fixture
def proyecto_puntos_ajeno_con_plano(
    db_session,
    otro_tecnico_puntos: Usuario,
    cliente_puntos: Cliente,
) -> tuple[Proyecto, Plano]:
    proyecto = Proyecto(
        nombre="Proyecto Puntos Ajeno",
        cliente_id=cliente_puntos.id,
        estado="en_progreso",
        tecnico_id=otro_tecnico_puntos.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)

    plano = Plano(
        proyecto_id=proyecto.id,
        nombre_archivo="ajeno-puntos.pdf",
        ruta_archivo="proyecto_ajeno_puntos/plano.pdf",
        mime_type="application/pdf",
        size_bytes=120,
        uploaded_by=otro_tecnico_puntos.id,
    )
    db_session.add(plano)
    db_session.commit()
    db_session.refresh(plano)
    return proyecto, plano


def payload_punto(plano_id: int, **overrides) -> dict:
    body = {
        "plano_id": plano_id,
        "x": 0.42,
        "y": 0.67,
        "modo": "manual",
        "etiqueta": "Punto 1",
        "descripcion": "Entrada principal",
    }
    body.update(overrides)
    return body


def payload_wifi(plano_id: int, *, punto_id: str | None = None) -> dict:
    return {
        "plano_id": plano_id,
        "punto_id": punto_id,
        "capturado_en": datetime(2026, 5, 19, 12, 34, 56, tzinfo=timezone.utc).isoformat(),
        "origen": "mobile",
        "app_version": "1.0.0",
        "device_id": "android-device-id",
        "senales": [
            {
                "ssid": "Bulldog-5G",
                "bssid": "AA:BB:CC:DD:EE:FF",
                "rssi_dbm": -61,
                "frequency_mhz": 5180,
                "channel": 36,
                "security": "[WPA2-PSK-CCMP][ESS]",
            }
        ],
    }


def test_crear_punto_valido_retorna_201(
    client: TestClient,
    tecnico_token: str,
    proyecto_puntos_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_puntos_con_plano
    response = client.post(
        f"/proyectos/{proyecto.id}/puntos-medicion",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(plano.id),
    )

    assert response.status_code == 201
    data = response.json()
    assert data["proyecto_id"] == proyecto.id
    assert data["plano_id"] == plano.id
    assert data["x"] == 0.42
    assert data["y"] == 0.67
    assert data["modo"] == "manual"


def test_listar_puntos_retorna_200(
    client: TestClient,
    tecnico_token: str,
    proyecto_puntos_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_puntos_con_plano
    client.post(
        f"/proyectos/{proyecto.id}/puntos-medicion",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(plano.id),
    )

    response = client.get(
        f"/proyectos/{proyecto.id}/puntos-medicion",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )
    assert response.status_code == 200
    assert len(response.json()) == 1


def test_editar_punto_retorna_200(
    client: TestClient,
    tecnico_token: str,
    proyecto_puntos_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_puntos_con_plano
    creado = client.post(
        f"/proyectos/{proyecto.id}/puntos-medicion",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(plano.id),
    ).json()

    response = client.put(
        f"/proyectos/{proyecto.id}/puntos-medicion/{creado['id']}",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(plano.id, x=0.5, y=0.5, modo="continuo", etiqueta="Punto 2"),
    )

    assert response.status_code == 200
    data = response.json()
    assert data["x"] == 0.5
    assert data["y"] == 0.5
    assert data["modo"] == "continuo"
    assert data["etiqueta"] == "Punto 2"


def test_eliminar_punto_retorna_204(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_puntos_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_puntos_con_plano
    creado = client.post(
        f"/proyectos/{proyecto.id}/puntos-medicion",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(plano.id),
    ).json()

    response = client.delete(
        f"/proyectos/{proyecto.id}/puntos-medicion/{creado['id']}",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 204
    punto = db_session.query(PuntoMedicion).filter(PuntoMedicion.id == creado["id"]).first()
    assert punto is None


def test_proyecto_ajeno_retorna_404(
    client: TestClient,
    tecnico_token: str,
    proyecto_puntos_ajeno_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_puntos_ajeno_con_plano
    response = client.post(
        f"/proyectos/{proyecto.id}/puntos-medicion",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(plano.id),
    )
    assert response.status_code == 404


def test_proyecto_archivado_retorna_409(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_puntos_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_puntos_con_plano
    proyecto.estado = "archivado"
    db_session.commit()

    response = client.post(
        f"/proyectos/{proyecto.id}/puntos-medicion",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(plano.id),
    )
    assert response.status_code == 409


def test_proyecto_sin_plano_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_puntos_sin_plano: Proyecto,
):
    response = client.post(
        f"/proyectos/{proyecto_puntos_sin_plano.id}/puntos-medicion",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(999),
    )
    assert response.status_code == 409


def test_xy_invalidos_retorna_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_puntos_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_puntos_con_plano
    x_invalido = client.post(
        f"/proyectos/{proyecto.id}/puntos-medicion",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(plano.id, x=1.5),
    )
    y_invalido = client.post(
        f"/proyectos/{proyecto.id}/puntos-medicion",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(plano.id, y=-0.1),
    )
    assert x_invalido.status_code == 422
    assert y_invalido.status_code == 422


def test_plano_incorrecto_retorna_409(
    client: TestClient,
    tecnico_token: str,
    proyecto_puntos_con_plano: tuple[Proyecto, Plano],
    proyecto_puntos_ajeno_con_plano: tuple[Proyecto, Plano],
):
    proyecto, _ = proyecto_puntos_con_plano
    _, plano_ajeno = proyecto_puntos_ajeno_con_plano
    response = client.post(
        f"/proyectos/{proyecto.id}/puntos-medicion",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(plano_ajeno.id),
    )
    assert response.status_code == 409


def test_punto_ajeno_o_inexistente_retorna_404(
    client: TestClient,
    tecnico_token: str,
    proyecto_puntos_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_puntos_con_plano
    response = client.put(
        f"/proyectos/{proyecto.id}/puntos-medicion/999999",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(plano.id),
    )
    assert response.status_code == 404


def test_pb03_sigue_funcionando(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_puntos_con_plano: tuple[Proyecto, Plano],
):
    proyecto, plano = proyecto_puntos_con_plano
    punto = client.post(
        f"/proyectos/{proyecto.id}/puntos-medicion",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_punto(plano.id),
    ).json()

    response = client.post(
        f"/proyectos/{proyecto.id}/wifi-scans",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        json=payload_wifi(plano.id, punto_id=str(punto["id"])),
    )

    assert response.status_code == 201
    lote = db_session.query(WifiScanLote).filter(WifiScanLote.id == response.json()["id"]).first()
    assert lote is not None
    assert lote.punto_id == str(punto["id"])
