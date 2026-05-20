from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.models.cliente import Cliente
from app.models.plano import Plano
from app.models.proyecto import Proyecto
from app.models.usuario import Usuario


@pytest.fixture
def plano_storage_tmp(tmp_path, monkeypatch) -> Path:
    storage_dir = tmp_path / "planos"
    monkeypatch.setattr(settings, "plano_storage_dir", str(storage_dir))
    monkeypatch.setattr(settings, "plano_max_size_bytes", 1024)
    return storage_dir


@pytest.fixture
def cliente_seed(db_session) -> Cliente:
    cliente = Cliente(nombre="Cliente Planos")
    db_session.add(cliente)
    db_session.commit()
    db_session.refresh(cliente)
    return cliente


@pytest.fixture
def proyecto_propio(db_session, tecnico_usuario: Usuario, cliente_seed: Cliente) -> Proyecto:
    proyecto = Proyecto(
        nombre="Proyecto con plano",
        cliente_id=cliente_seed.id,
        estado="en_progreso",
        tecnico_id=tecnico_usuario.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)
    return proyecto


@pytest.fixture
def otro_tecnico(db_session) -> Usuario:
    usuario = Usuario(
        nombre="Otro Técnico",
        email="otro.tecnico@test.bo",
        password_hash="hash-no-importa",
        rol="tecnico",
        activo=True,
    )
    db_session.add(usuario)
    db_session.commit()
    db_session.refresh(usuario)
    return usuario


@pytest.fixture
def proyecto_ajeno(db_session, otro_tecnico: Usuario, cliente_seed: Cliente) -> Proyecto:
    proyecto = Proyecto(
        nombre="Proyecto ajeno",
        cliente_id=cliente_seed.id,
        estado="en_progreso",
        tecnico_id=otro_tecnico.id,
    )
    db_session.add(proyecto)
    db_session.commit()
    db_session.refresh(proyecto)
    return proyecto


def test_subir_plano_pdf_crea_metadata_y_archivo(
    client: TestClient,
    tecnico_token: str,
    proyecto_propio: Proyecto,
    plano_storage_tmp: Path,
):
    response = client.post(
        f"/proyectos/{proyecto_propio.id}/plano",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        files={"archivo": ("plano.pdf", b"%PDF-1.4 plano demo", "application/pdf")},
    )

    assert response.status_code == 201
    data = response.json()
    assert data["proyecto_id"] == proyecto_propio.id
    assert data["nombre_archivo"] == "plano.pdf"
    assert data["mime_type"] == "application/pdf"
    assert data["size_bytes"] > 0
    assert any(plano_storage_tmp.rglob("*.pdf"))


def test_get_plano_retorna_metadata(
    client: TestClient,
    tecnico_token: str,
    proyecto_propio: Proyecto,
    plano_storage_tmp: Path,
):
    client.post(
        f"/proyectos/{proyecto_propio.id}/plano",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        files={"archivo": ("plano.png", b"\x89PNG\r\n\x1a\ncontenido", "image/png")},
    )

    response = client.get(
        f"/proyectos/{proyecto_propio.id}/plano",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    assert response.json()["nombre_archivo"] == "plano.png"


def test_download_plano_retorna_archivo(
    client: TestClient,
    tecnico_token: str,
    proyecto_propio: Proyecto,
    plano_storage_tmp: Path,
):
    contenido = b"\xff\xd8\xff\xe0jpg-demo"
    client.post(
        f"/proyectos/{proyecto_propio.id}/plano",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        files={"archivo": ("plano.jpg", contenido, "image/jpeg")},
    )

    response = client.get(
        f"/proyectos/{proyecto_propio.id}/plano/download",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 200
    assert response.content == contenido
    assert response.headers["content-type"] == "image/jpeg"
    assert "plano.jpg" in response.headers["content-disposition"]


def test_nueva_subida_reemplaza_plano_anterior_y_borra_archivo_viejo(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_propio: Proyecto,
    plano_storage_tmp: Path,
):
    primera = client.post(
        f"/proyectos/{proyecto_propio.id}/plano",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        files={"archivo": ("primero.pdf", b"%PDF-1.4 primero", "application/pdf")},
    )
    assert primera.status_code == 201

    plano = db_session.query(Plano).filter(Plano.proyecto_id == proyecto_propio.id).first()
    assert plano is not None
    ruta_vieja = plano.ruta_archivo
    archivo_viejo = plano_storage_tmp / ruta_vieja
    assert archivo_viejo.exists()

    segunda = client.post(
        f"/proyectos/{proyecto_propio.id}/plano",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        files={"archivo": ("segundo.pdf", b"%PDF-1.4 segundo", "application/pdf")},
    )
    assert segunda.status_code == 201

    plano_actual = db_session.query(Plano).filter(Plano.proyecto_id == proyecto_propio.id).all()
    assert len(plano_actual) == 1
    assert plano_actual[0].nombre_archivo == "segundo.pdf"
    assert plano_actual[0].ruta_archivo != ruta_vieja
    assert not archivo_viejo.exists()
    assert (plano_storage_tmp / plano_actual[0].ruta_archivo).exists()


def test_proyecto_ajeno_devuelve_404(
    client: TestClient,
    tecnico_token: str,
    proyecto_ajeno: Proyecto,
    plano_storage_tmp: Path,
):
    response = client.post(
        f"/proyectos/{proyecto_ajeno.id}/plano",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        files={"archivo": ("plano.pdf", b"%PDF-1.4 demo", "application/pdf")},
    )

    assert response.status_code == 404


def test_proyecto_archivado_devuelve_409(
    client: TestClient,
    db_session,
    tecnico_token: str,
    proyecto_propio: Proyecto,
    plano_storage_tmp: Path,
):
    proyecto_propio.estado = "archivado"
    db_session.commit()

    response = client.post(
        f"/proyectos/{proyecto_propio.id}/plano",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        files={"archivo": ("plano.pdf", b"%PDF-1.4 demo", "application/pdf")},
    )

    assert response.status_code == 409


def test_formato_no_permitido_devuelve_415(
    client: TestClient,
    tecnico_token: str,
    proyecto_propio: Proyecto,
    plano_storage_tmp: Path,
):
    response = client.post(
        f"/proyectos/{proyecto_propio.id}/plano",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        files={"archivo": ("plano.txt", b"texto", "text/plain")},
    )

    assert response.status_code == 415


def test_archivo_obligatorio_devuelve_422(
    client: TestClient,
    tecnico_token: str,
    proyecto_propio: Proyecto,
    plano_storage_tmp: Path,
):
    response = client.post(
        f"/proyectos/{proyecto_propio.id}/plano",
        headers={"Authorization": f"Bearer {tecnico_token}"},
    )

    assert response.status_code == 422


def test_tamano_maximo_configurable_devuelve_413(
    client: TestClient,
    tecnico_token: str,
    proyecto_propio: Proyecto,
    plano_storage_tmp: Path,
):
    response = client.post(
        f"/proyectos/{proyecto_propio.id}/plano",
        headers={"Authorization": f"Bearer {tecnico_token}"},
        files={"archivo": ("plano.pdf", b"x" * 2048, "application/pdf")},
    )

    assert response.status_code == 413
