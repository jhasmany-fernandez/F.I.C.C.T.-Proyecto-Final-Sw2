from sqlalchemy.orm import Session

from app.models.proyecto import Proyecto
from app.models.punto_medicion import PuntoMedicion
from app.schemas.punto_medicion import PuntoMedicionIn


class PuntoMedicionRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def listar_por_proyecto(self, *, proyecto_id: int) -> list[PuntoMedicion]:
        return (
            self._db.query(PuntoMedicion)
            .filter(PuntoMedicion.proyecto_id == proyecto_id)
            .order_by(PuntoMedicion.created_at.asc(), PuntoMedicion.id.asc())
            .all()
        )

    def obtener_por_id(self, *, proyecto_id: int, punto_id: int) -> PuntoMedicion | None:
        return (
            self._db.query(PuntoMedicion)
            .filter(
                PuntoMedicion.id == punto_id,
                PuntoMedicion.proyecto_id == proyecto_id,
            )
            .first()
        )

    def crear(self, *, proyecto: Proyecto, body: PuntoMedicionIn) -> PuntoMedicion:
        punto = PuntoMedicion(
            proyecto_id=proyecto.id,
            plano_id=body.plano_id,
            x=body.x,
            y=body.y,
            modo=body.modo,
            etiqueta=body.etiqueta,
            descripcion=body.descripcion,
        )
        self._db.add(punto)
        proyecto.cantidad_puntos = (proyecto.cantidad_puntos or 0) + 1
        self._db.commit()
        self._db.refresh(punto)
        return punto

    def actualizar(self, *, punto: PuntoMedicion, body: PuntoMedicionIn) -> PuntoMedicion:
        punto.plano_id = body.plano_id
        punto.x = body.x
        punto.y = body.y
        punto.modo = body.modo
        punto.etiqueta = body.etiqueta
        punto.descripcion = body.descripcion
        self._db.commit()
        self._db.refresh(punto)
        return punto

    def eliminar(self, *, proyecto: Proyecto, punto: PuntoMedicion) -> None:
        self._db.delete(punto)
        proyecto.cantidad_puntos = max((proyecto.cantidad_puntos or 0) - 1, 0)
        self._db.commit()
