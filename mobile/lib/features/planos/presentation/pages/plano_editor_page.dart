import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/plano.dart';
import '../cubit/planos_cubit.dart';
import '../cubit/planos_state.dart';
import '../utils/url_resolver.dart';

/// Página del editor de plano: visualiza la imagen y permite calibrar la
/// escala (PB-11) seleccionando dos puntos sobre el plano e indicando la
/// distancia real entre ellos.
class PlanoEditorPage extends StatefulWidget {
  final Plano plano;

  const PlanoEditorPage({super.key, required this.plano});

  @override
  State<PlanoEditorPage> createState() => _PlanoEditorPageState();
}

class _PlanoEditorPageState extends State<PlanoEditorPage> {
  /// Modo activo de calibración: en true, los taps marcan puntos.
  bool _modoCalibracion = false;

  /// Puntos seleccionados en coordenadas de imagen (px del plano original).
  Offset? _puntoA;
  Offset? _puntoB;

  /// Punto que se está arrastrando actualmente ('A', 'B' o null).
  String? _puntoArrastrado;

  /// Posición del último onTapDown; usada por onTap para colocar un punto.
  Offset? _ultimoTapDown;

  /// Radio (en px de pantalla) de la zona sensible para seleccionar un punto.
  static const double _hitRadioPx = 24.0;

  /// Tamaño actual del widget que muestra la imagen (en px de pantalla).
  Size _renderSize = Size.zero;

  /// Controlador de transformación del InteractiveViewer.
  /// Permite leer el nivel de zoom actual para compensar el radio de los
  /// puntos de calibración y mantenerlos con tamaño visual constante.
  late final TransformationController _transformController;

  /// Escala actual del InteractiveViewer (1.0 = sin zoom).
  double _zoomEscala = 1.0;

  late Plano _plano;

  // ── Modo Regla (ruler) — Sp2-17 / CA-4 PB-11 ──────────────────────────────
  bool _modoRegla = false;
  Offset? _reglaA;
  Offset? _reglaB;
  String? _reglaArrastrado;

  /// Distancia en metros entre los dos puntos de la regla.
  /// Requiere que el plano esté calibrado y ambos puntos definidos.
  double? get _distanciaReglaM {
    if (_reglaA == null || _reglaB == null || !_plano.calibrado) return null;
    final distPx = (_reglaB! - _reglaA!).distance;
    return distPx * _plano.escalaMPorPx!;
  }

  @override
  void initState() {
    super.initState();
    _plano = widget.plano;
    _transformController = TransformationController();
    _transformController.addListener(() {
      final escala = _transformController.value.getMaxScaleOnAxis();
      if (escala != _zoomEscala) {
        setState(() => _zoomEscala = escala);
      }
    });
    if (_plano.calibrado) {
      _puntoA = Offset(_plano.calibracionX1!, _plano.calibracionY1!);
      _puntoB = Offset(_plano.calibracionX2!, _plano.calibracionY2!);
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  /// Convierte un tap (en px de pantalla) a coordenadas en px del plano.
  Offset _tapAImagen(Offset tap) {
    if (_renderSize == Size.zero) return Offset.zero;
    final factorX = _plano.anchoPx / _renderSize.width;
    final factorY = _plano.altoPx / _renderSize.height;
    return Offset(tap.dx * factorX, tap.dy * factorY);
  }

  /// Convierte coordenadas del plano a px de pantalla para pintar overlays.
  Offset _imagenAPantalla(Offset puntoImagen) {
    if (_renderSize == Size.zero) return Offset.zero;
    final factorX = _renderSize.width / _plano.anchoPx;
    final factorY = _renderSize.height / _plano.altoPx;
    return Offset(puntoImagen.dx * factorX, puntoImagen.dy * factorY);
  }

  /// Devuelve true si [localPos] (coords del GestureDetector) está dentro del
  /// radio de toque del [puntoImagen] (coords de imagen).
  bool _tocaPunto(Offset localPos, Offset? puntoImagen) {
    if (puntoImagen == null) return false;
    final pantalla = _imagenAPantalla(puntoImagen);
    return (localPos - pantalla).distance <= _hitRadioPx / _zoomEscala;
  }

  /// Guarda la posición del toque para usarla en [_onTap].
  void _onTapDown(TapDownDetails details) {
    _ultimoTapDown = details.localPosition;
  }

  /// Coloca un nuevo punto solo si el toque no está sobre uno existente.
  void _onTap() {
    final pos = _ultimoTapDown;
    if (pos == null) return;
    if (_modoCalibracion) {
      if (_tocaPunto(pos, _puntoA) || _tocaPunto(pos, _puntoB)) return;
      final puntoImagen = _tapAImagen(pos);
      setState(() {
        if (_puntoA == null || (_puntoA != null && _puntoB != null)) {
          _puntoA = puntoImagen;
          _puntoB = null;
        } else {
          _puntoB = puntoImagen;
        }
      });
    } else if (_modoRegla) {
      if (_tocaPunto(pos, _reglaA) || _tocaPunto(pos, _reglaB)) return;
      final puntoImagen = _tapAImagen(pos);
      setState(() {
        if (_reglaA == null || (_reglaA != null && _reglaB != null)) {
          _reglaA = puntoImagen;
          _reglaB = null;
        } else {
          _reglaB = puntoImagen;
        }
      });
    }
  }

  /// Inicia el arrastre si el gesto comienza sobre un punto existente.
  void _onPanStart(DragStartDetails details) {
    final pos = details.localPosition;
    if (_modoCalibracion) {
      if (_tocaPunto(pos, _puntoA)) {
        setState(() => _puntoArrastrado = 'A');
      } else if (_tocaPunto(pos, _puntoB)) {
        setState(() => _puntoArrastrado = 'B');
      }
    } else if (_modoRegla) {
      if (_tocaPunto(pos, _reglaA)) {
        setState(() => _reglaArrastrado = 'A');
      } else if (_tocaPunto(pos, _reglaB)) {
        setState(() => _reglaArrastrado = 'B');
      }
    }
  }

  /// Mueve el punto seleccionado siguiendo el dedo.
  void _onPanUpdate(DragUpdateDetails details) {
    final puntoImagen = _tapAImagen(details.localPosition);
    if (_modoCalibracion && _puntoArrastrado != null) {
      setState(() {
        if (_puntoArrastrado == 'A') {
          _puntoA = puntoImagen;
        } else {
          _puntoB = puntoImagen;
        }
      });
    } else if (_modoRegla && _reglaArrastrado != null) {
      setState(() {
        if (_reglaArrastrado == 'A') {
          _reglaA = puntoImagen;
        } else {
          _reglaB = puntoImagen;
        }
      });
    }
  }

  /// Suelta el punto arrastrado.
  void _onPanEnd(DragEndDetails details) {
    if (_puntoArrastrado != null) {
      setState(() => _puntoArrastrado = null);
    }
    if (_reglaArrastrado != null) {
      setState(() => _reglaArrastrado = null);
    }
  }

  Future<void> _confirmarCalibracion() async {
    if (_puntoA == null || _puntoB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marca los dos puntos sobre el plano.')),
      );
      return;
    }
    final distancia = await _pedirDistancia();
    if (distancia == null) return;
    if (!mounted) return;
    await context.read<PlanosCubit>().calibrarPlano(
          planoId: _plano.id,
          x1: _puntoA!.dx,
          y1: _puntoA!.dy,
          x2: _puntoB!.dx,
          y2: _puntoB!.dy,
          distanciaRealM: distancia,
        );
  }

  Future<double?> _pedirDistancia() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Distancia real'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Metros entre los dos puntos',
              suffixText: 'm',
              hintText: 'Ej. 5.20',
            ),
            validator: (value) {
              final v = double.tryParse((value ?? '').replaceAll(',', '.'));
              if (v == null) return 'Ingresa un número válido.';
              if (v < 1) return 'Debe ser ≥ 1 metro.';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final v = double.parse(
                controller.text.replaceAll(',', '.'),
              );
              Navigator.of(ctx).pop(v);
            },
            child: const Text('Calibrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = resolverUrlFirmada(_plano.urlFirmada);
    return BlocListener<PlanosCubit, PlanosState>(
      listener: (context, state) {
        if (state is PlanosOperacionExitosa &&
            state.planoAfectado != null &&
            state.planoAfectado!.id == _plano.id) {
          setState(() {
            _plano = state.planoAfectado!;
            _modoCalibracion = false;
            _puntoA = Offset(_plano.calibracionX1!, _plano.calibracionY1!);
            _puntoB = Offset(_plano.calibracionX2!, _plano.calibracionY2!);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_plano.nombre),
          actions: [
            if (_plano.calibrado && !_modoCalibracion)
              IconButton(
                tooltip: _modoRegla ? 'Cerrar regla' : 'Medir distancia',
                icon: Icon(
                  _modoRegla ? Icons.close : Icons.square_foot,
                ),
                onPressed: () => setState(() {
                  _modoRegla = !_modoRegla;
                  if (!_modoRegla) {
                    _reglaA = null;
                    _reglaB = null;
                  }
                }),
              ),
            if (!_modoRegla)
              IconButton(
                tooltip: _modoCalibracion
                    ? 'Cancelar calibración'
                    : 'Calibrar escala',
                icon: Icon(_modoCalibracion ? Icons.close : Icons.straighten),
                onPressed: () => setState(() {
                  _modoCalibracion = !_modoCalibracion;
                  if (_modoCalibracion) {
                    _modoRegla = false;
                    _reglaA = null;
                    _reglaB = null;
                  }
                  if (!_modoCalibracion && !_plano.calibrado) {
                    _puntoA = null;
                    _puntoB = null;
                  }
                }),
              ),
          ],
        ),
        body: Column(
          children: [
            _StatusBar(
              plano: _plano,
              modoCalibracion: _modoCalibracion,
              modoRegla: _modoRegla,
              distanciaReglaM: _distanciaReglaM,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Mantener el aspect ratio del plano dentro del Box.
                  final aspect = _plano.anchoPx / _plano.altoPx;
                  double w = constraints.maxWidth;
                  double h = w / aspect;
                  if (h > constraints.maxHeight) {
                    h = constraints.maxHeight;
                    w = h * aspect;
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_renderSize != Size(w, h)) {
                      setState(() => _renderSize = Size(w, h));
                    }
                  });
                  return Center(
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        panEnabled: !_modoCalibracion && !_modoRegla,
                        scaleEnabled: !_modoCalibracion && !_modoRegla,
                        child: GestureDetector(
                          onTapDown: _onTapDown,
                          onTap:
                              (_modoCalibracion || _modoRegla) ? _onTap : null,
                          onPanStart: (_modoCalibracion || _modoRegla)
                              ? _onPanStart
                              : null,
                          onPanUpdate: (_modoCalibracion || _modoRegla)
                              ? _onPanUpdate
                              : null,
                          onPanEnd: (_modoCalibracion || _modoRegla)
                              ? _onPanEnd
                              : null,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                url,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'No se pudo cargar la imagen del plano. '
                                      'La URL pudo expirar; vuelve a entrar al editor.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                              if (_puntoA != null || _puntoB != null)
                                CustomPaint(
                                  painter: _CalibracionPainter(
                                    puntoA: _puntoA == null
                                        ? null
                                        : _imagenAPantalla(_puntoA!),
                                    puntoB: _puntoB == null
                                        ? null
                                        : _imagenAPantalla(_puntoB!),
                                    zoomEscala: _zoomEscala,
                                    puntoArrastrado: _puntoArrastrado,
                                  ),
                                ),
                              if (_reglaA != null || _reglaB != null)
                                CustomPaint(
                                  painter: _ReglaPainter(
                                    puntoA: _reglaA == null
                                        ? null
                                        : _imagenAPantalla(_reglaA!),
                                    puntoB: _reglaB == null
                                        ? null
                                        : _imagenAPantalla(_reglaB!),
                                    distanciaM: _distanciaReglaM,
                                    zoomEscala: _zoomEscala,
                                    puntoArrastrado: _reglaArrastrado,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _modoCalibracion
            ? FloatingActionButton.extended(
                onPressed: _confirmarCalibracion,
                icon: const Icon(Icons.check),
                label: const Text('Confirmar'),
              )
            : (_plano.calibrado
                ? FloatingActionButton.extended(
                    onPressed: () => context.pushNamed(
                      'captura',
                      pathParameters: {
                        'id': _plano.proyectoId.toString(),
                        'planoId': _plano.id.toString(),
                      },
                      extra: {
                        'planoId': _plano.id,
                        'imagenUrl': resolverUrlFirmada(_plano.urlFirmada),
                        'anchoPlanoPx': _plano.anchoPx.toDouble(),
                        'altoPlanoPx': _plano.altoPx.toDouble(),
                      },
                    ),
                    icon: const Icon(Icons.wifi_find),
                    label: const Text('Iniciar captura'),
                  )
                : null),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final Plano plano;
  final bool modoCalibracion;
  final bool modoRegla;
  final double? distanciaReglaM;

  const _StatusBar({
    required this.plano,
    required this.modoCalibracion,
    this.modoRegla = false,
    this.distanciaReglaM,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (Color bgColor, Color fgColor) = modoCalibracion
        ? (scheme.tertiaryContainer, scheme.onTertiaryContainer)
        : modoRegla
            ? (scheme.secondaryContainer, scheme.onSecondaryContainer)
            : (plano.calibrado
                ? (scheme.primaryContainer, scheme.onPrimaryContainer)
                : (scheme.errorContainer, scheme.onErrorContainer));

    final texto = modoCalibracion
        ? 'Modo calibración: toca para marcar · mantén presionado un punto para moverlo.'
        : modoRegla
            ? (distanciaReglaM != null
                ? 'Distancia: ${distanciaReglaM!.toStringAsFixed(2)} m'
                : 'Modo regla: toca dos puntos del plano para medir la distancia en metros.')
            : (plano.calibrado
                ? 'Calibrado · ${plano.escalaMPorPx!.toStringAsFixed(4)} m/px '
                    '(${plano.distanciaRealM!.toStringAsFixed(2)} m)'
                : 'Sin calibrar. Toca el ícono de la regla para iniciar.');
    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        texto,
        style: textTheme.bodyMedium?.copyWith(color: fgColor),
      ),
    );
  }
}

class _CalibracionPainter extends CustomPainter {
  final Offset? puntoA;
  final Offset? puntoB;

  /// Escala actual del InteractiveViewer. Se usa para mantener el tamaño
  /// visual de los puntos constante independientemente del nivel de zoom.
  final double zoomEscala;

  /// Punto que se está arrastrando ('A', 'B' o null). Recibe un estilo
  /// visual diferenciado para indicar que está seleccionado.
  final String? puntoArrastrado;

  _CalibracionPainter({
    this.puntoA,
    this.puntoB,
    this.zoomEscala = 1.0,
    this.puntoArrastrado,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radio = 3.0 / zoomEscala;
    final radioSeleccionado = 5.0 / zoomEscala;

    final paintLinea = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 1.5 / zoomEscala
      ..style = PaintingStyle.stroke;
    final paintNormal = Paint()..color = Colors.redAccent;
    final paintSeleccionado = Paint()..color = Colors.red.shade700;
    final paintAnillo = Paint()
      ..color = Colors.red.shade700
      ..strokeWidth = 1.5 / zoomEscala
      ..style = PaintingStyle.stroke;

    if (puntoA != null && puntoB != null) {
      canvas.drawLine(puntoA!, puntoB!, paintLinea);
    }

    _pintarPunto(canvas, puntoA, 'A', radio, radioSeleccionado, paintNormal,
        paintSeleccionado, paintAnillo);
    _pintarPunto(canvas, puntoB, 'B', radio, radioSeleccionado, paintNormal,
        paintSeleccionado, paintAnillo);
  }

  void _pintarPunto(
    Canvas canvas,
    Offset? punto,
    String nombre,
    double radio,
    double radioSel,
    Paint paintNormal,
    Paint paintSel,
    Paint paintAnillo,
  ) {
    if (punto == null) return;
    if (puntoArrastrado == nombre) {
      // Círculo relleno más grande + anillo exterior para retroalimentación táctil.
      canvas.drawCircle(punto, radioSel, paintSel);
      canvas.drawCircle(punto, radioSel + 4.0 / zoomEscala, paintAnillo);
    } else {
      canvas.drawCircle(punto, radio, paintNormal);
    }
  }

  @override
  bool shouldRepaint(covariant _CalibracionPainter old) {
    return old.puntoA != puntoA ||
        old.puntoB != puntoB ||
        old.zoomEscala != zoomEscala ||
        old.puntoArrastrado != puntoArrastrado;
  }
}

/// Pintor de la herramienta regla — Sp2-17 / CA-4 PB-11.
/// Dibuja una línea azul entre los dos puntos de medición y la distancia
/// calculada en metros en una etiqueta flotante sobre la línea.
class _ReglaPainter extends CustomPainter {
  final Offset? puntoA;
  final Offset? puntoB;
  final double? distanciaM;
  final double zoomEscala;
  final String? puntoArrastrado;

  _ReglaPainter({
    this.puntoA,
    this.puntoB,
    this.distanciaM,
    this.zoomEscala = 1.0,
    this.puntoArrastrado,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radio = 3.0 / zoomEscala;
    final radioSel = 5.0 / zoomEscala;

    final paintLinea = Paint()
      ..color = Colors.blue.shade600
      ..strokeWidth = 2.0 / zoomEscala
      ..style = PaintingStyle.stroke;
    final paintPunto = Paint()..color = Colors.blue.shade700;
    final paintPuntoSel = Paint()..color = Colors.blue.shade900;
    final paintAnillo = Paint()
      ..color = Colors.blue.shade900
      ..strokeWidth = 1.5 / zoomEscala
      ..style = PaintingStyle.stroke;

    if (puntoA != null && puntoB != null) {
      canvas.drawLine(puntoA!, puntoB!, paintLinea);
      if (distanciaM != null) {
        final mid = Offset(
          (puntoA!.dx + puntoB!.dx) / 2,
          (puntoA!.dy + puntoB!.dy) / 2,
        );
        final etiqueta = '${distanciaM!.toStringAsFixed(2)} m';
        final tamanoTexto = 12.0 / zoomEscala;
        final textPainter = TextPainter(
          text: TextSpan(
            text: etiqueta,
            style: TextStyle(
              color: Colors.white,
              fontSize: tamanoTexto,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final padding = 4.0 / zoomEscala;
        final rectW = textPainter.width + padding * 2;
        final rectH = textPainter.height + padding * 2;
        final bgRect = Rect.fromLTWH(
          mid.dx - rectW / 2,
          mid.dy - rectH / 2,
          rectW,
          rectH,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            bgRect,
            Radius.circular(3 / zoomEscala),
          ),
          Paint()..color = Colors.blue.shade700,
        );
        textPainter.paint(
          canvas,
          Offset(bgRect.left + padding, bgRect.top + padding),
        );
      }
    }

    _pintarPunto(canvas, puntoA, 'A', radio, radioSel, paintPunto,
        paintPuntoSel, paintAnillo);
    _pintarPunto(canvas, puntoB, 'B', radio, radioSel, paintPunto,
        paintPuntoSel, paintAnillo);
  }

  void _pintarPunto(
    Canvas canvas,
    Offset? punto,
    String nombre,
    double radio,
    double radioSel,
    Paint paintNormal,
    Paint paintSel,
    Paint paintAnillo,
  ) {
    if (punto == null) return;
    if (puntoArrastrado == nombre) {
      canvas.drawCircle(punto, radioSel, paintSel);
      canvas.drawCircle(punto, radioSel + 4.0 / zoomEscala, paintAnillo);
    } else {
      canvas.drawCircle(punto, radio, paintNormal);
    }
  }

  @override
  bool shouldRepaint(covariant _ReglaPainter old) {
    return old.puntoA != puntoA ||
        old.puntoB != puntoB ||
        old.distanciaM != distanciaM ||
        old.zoomEscala != zoomEscala ||
        old.puntoArrastrado != puntoArrastrado;
  }
}
