from sqlalchemy.orm import Session

from app.models.punto_medicion import PuntoMedicion
from app.models.wifi_scan import WifiScanLote, WifiScanSenal
from app.schemas.wifi_scan import WifiScanLoteIn


class WifiScanRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def crear_lote(
        self,
        *,
        proyecto_id: int,
        tecnico_id: int,
        body: WifiScanLoteIn,
        punto_medicion: PuntoMedicion | None = None,
        punto_id_legacy: str | None = None,
    ) -> WifiScanLote:
        lote = WifiScanLote(
            proyecto_id=proyecto_id,
            plano_id=body.plano_id,
            tecnico_id=tecnico_id,
            punto_medicion_id=punto_medicion.id if punto_medicion else None,
            punto_id=punto_id_legacy,
            capturado_en=body.capturado_en,
            origen=body.origen,
            app_version=body.app_version,
            device_id=body.device_id,
        )
        lote.senales = [
            WifiScanSenal(
                ssid=senal.ssid,
                bssid=senal.bssid,
                rssi_dbm=senal.rssi_dbm,
                frequency_mhz=senal.frequency_mhz,
                channel=senal.channel,
                security=senal.security,
            )
            for senal in body.senales
        ]
        self._db.add(lote)
        self._db.commit()
        self._db.refresh(lote)
        return lote
