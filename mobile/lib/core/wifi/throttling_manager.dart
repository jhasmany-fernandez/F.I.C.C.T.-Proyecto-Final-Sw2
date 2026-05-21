/// Gestor de throttling de escaneos WiFi para Android ≥ 8.0.
///
/// Android impone un límite de 4 escaneos cada 2 minutos cuando la app
/// está en background. [ThrottlingManager] registra los timestamps de los
/// últimos escaneos y expone:
///   - [puedeEscanear] → bool
///   - [segundosHastaProximo] → int (0 si puede escanear ya)
///   - [registrarEscaneo] → registra un nuevo escaneo
///
/// Sprint 3 — PB-03 (Sp3-09).
/// Ref: CWNA-107 §4.3 — Throttling Android ≥ 8.0 = 4 scans / 2 min.
class ThrottlingManager {
  static const int kMaxEscaneos = 4;
  static const Duration kVentana = Duration(minutes: 2);

  final List<DateTime> _registros = [];

  /// `true` si se puede realizar otro escaneo dentro del límite permitido.
  bool get puedeEscanear {
    _limpiarViejos();
    return _registros.length < kMaxEscaneos;
  }

  /// Segundos restantes hasta que se libere un slot de escaneo.
  /// Retorna 0 si [puedeEscanear] es `true`.
  int get segundosHastaProximo {
    _limpiarViejos();
    if (_registros.length < kMaxEscaneos) return 0;
    final masAntiguo = _registros.first;
    final liberaEn = masAntiguo.add(kVentana);
    final restante = liberaEn.difference(DateTime.now());
    return restante.isNegative ? 0 : restante.inSeconds + 1;
  }

  /// Registra que se realizó un nuevo escaneo ahora.
  void registrarEscaneo() {
    _limpiarViejos();
    _registros.add(DateTime.now());
  }

  /// Número de escaneos realizados en la ventana actual.
  int get escaneosenVentana {
    _limpiarViejos();
    return _registros.length;
  }

  void _limpiarViejos() {
    final corte = DateTime.now().subtract(kVentana);
    _registros.removeWhere((t) => t.isBefore(corte));
  }
}
