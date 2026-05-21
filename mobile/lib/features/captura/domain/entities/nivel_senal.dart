/// Nivel de señal WiFi según umbrales CWNA-107.
///
/// Clasificación por RSSI:
///   verde    ≥ −70 dBm  → cobertura óptima
///   amarillo −70..−80   → aceptable
///   naranja  −80..−85   → pobre
///   rojo     −85..−90   → muy pobre
///   negro    < −90 dBm  → zona muerta (ZONA_MUERTA)
enum NivelSenal {
  verde,
  amarillo,
  naranja,
  rojo,
  negro;

  /// Clasifica un valor RSSI según los umbrales CWNA-107.
  static NivelSenal desde(int rssi) {
    if (rssi >= -70) return NivelSenal.verde;
    if (rssi >= -80) return NivelSenal.amarillo;
    if (rssi >= -85) return NivelSenal.naranja;
    if (rssi >= -90) return NivelSenal.rojo;
    return NivelSenal.negro;
  }

  /// Parsea el string devuelto por el backend.
  static NivelSenal fromString(String valor) => switch (valor) {
        'verde' => NivelSenal.verde,
        'amarillo' => NivelSenal.amarillo,
        'naranja' => NivelSenal.naranja,
        'rojo' => NivelSenal.rojo,
        _ => NivelSenal.negro,
      };
}
