"""Modelo ORM para el plano principal de un proyecto de survey.

PB-02 — Sprint 2: subida de plano PNG/JPG/PDF por proyecto.
"""

from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


class Plano(Base):
    __tablename__ = "plano"
    __table_args__ = (UniqueConstraint("proyecto_id", name="uq_plano_proyecto_id"),)

    id = Column(Integer, primary_key=True, index=True)
    proyecto_id = Column(
        Integer,
        ForeignKey("proyecto.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    nombre_archivo = Column(String(255), nullable=False)
    ruta_archivo = Column(String(500), nullable=False, unique=True)
    mime_type = Column(String(100), nullable=False)
    size_bytes = Column(Integer, nullable=False)
    uploaded_by = Column(
        Integer,
        ForeignKey("usuario.id"),
        nullable=False,
        index=True,
    )
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    proyecto = relationship("Proyecto", back_populates="plano")
    uploaded_by_user = relationship("Usuario", back_populates="planos_subidos")
    wifi_scans = relationship("WifiScanLote", back_populates="plano")
    puntos_medicion = relationship("PuntoMedicion", back_populates="plano")
