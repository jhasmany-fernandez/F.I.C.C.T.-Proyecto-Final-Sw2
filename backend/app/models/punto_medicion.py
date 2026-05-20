"""Modelo ORM para puntos de medicion marcados sobre un plano.

PB-04 — Sprint 2: marcacion manual/continua de puntos de medicion.
"""

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship

from app.core.database import Base


class PuntoMedicion(Base):
    __tablename__ = "punto_medicion"

    id = Column(Integer, primary_key=True, index=True)
    proyecto_id = Column(
        Integer,
        ForeignKey("proyecto.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    plano_id = Column(
        Integer,
        ForeignKey("plano.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    x = Column(Float, nullable=False)
    y = Column(Float, nullable=False)
    modo = Column(String(20), nullable=False)
    etiqueta = Column(String(120), nullable=True)
    descripcion = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        nullable=True,
        server_default=func.now(),
        onupdate=func.now(),
    )

    proyecto = relationship("Proyecto", back_populates="puntos_medicion")
    plano = relationship("Plano", back_populates="puntos_medicion")
    wifi_scans = relationship("WifiScanLote", back_populates="punto_medicion")
