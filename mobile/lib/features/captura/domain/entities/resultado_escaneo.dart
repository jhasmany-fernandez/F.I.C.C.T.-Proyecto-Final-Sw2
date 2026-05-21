/// Dato de un BSSID escaneado localmente (antes de enviarlo al backend).
class ResultadoEscaneo {
  final String ssid;
  final String bssid;
  final int rssi;
  final int? canal;
  final int? frecuenciaMhz;

  const ResultadoEscaneo({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    this.canal,
    this.frecuenciaMhz,
  });
}
