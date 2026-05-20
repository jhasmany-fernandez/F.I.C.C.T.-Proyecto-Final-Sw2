"""Modelos ORM para lotes de captura WiFi en linea.

PB-03 — Sprint 2: recepcion de lotes de senales WiFi enviados por mobile.
"""

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship

from app.core.database import Base


class WifiScanLote(Base):
    __tablename__ = "wifi_scan_lote"

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
    tecnico_id = Column(
        Integer,
        ForeignKey("usuario.id"),
        nullable=False,
        index=True,
    )
    punto_medicion_id = Column(
        Integer,
        ForeignKey("punto_medicion.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    punto_id = Column(String(100), nullable=True)
    capturado_en = Column(DateTime(timezone=True), nullable=False)
    origen = Column(String(30), nullable=False, server_default="mobile")
    app_version = Column(String(50), nullable=True)
    device_id = Column(String(120), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    proyecto = relationship("Proyecto", back_populates="wifi_scans")
    plano = relationship("Plano", back_populates="wifi_scans")
    tecnico = relationship("Usuario", back_populates="wifi_scans")
    punto_medicion = relationship("PuntoMedicion", back_populates="wifi_scans")
    senales = relationship(
        "WifiScanSenal",
        back_populates="lote",
        cascade="all, delete-orphan",
    )


class WifiScanSenal(Base):
    __tablename__ = "wifi_scan_senal"

    id = Column(Integer, primary_key=True, index=True)
    lote_id = Column(
        Integer,
        ForeignKey("wifi_scan_lote.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    ssid = Column(String(255), nullable=True)
    bssid = Column(String(17), nullable=False)
    rssi_dbm = Column(Integer, nullable=False)
    frequency_mhz = Column(Integer, nullable=True)
    channel = Column(Integer, nullable=True)
    security = Column(String(255), nullable=True)

    lote = relationship("WifiScanLote", back_populates="senales")
