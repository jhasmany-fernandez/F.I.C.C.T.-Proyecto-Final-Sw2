import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/punto_medicion.dart';
import '../cubit/captura_cubit.dart';
import '../cubit/captura_state.dart';
import '../widgets/plano_puntos_painter.dart';
import '../widgets/punto_detalle_sheet.dart';

/// Página de captura WiFi sobre plano.
/// Sprint 3 — PB-03, PB-04 (Sp3-17, Sp3-18, Sp3-19, Sp3-20, Sp3-21, Sp3-22).
///
/// Parámetros de ruta:
///   [planoId]      → id del plano en el que se captura.
///   [imagenUrl]    → URL de la imagen del plano.
///   [anchoPlanoPx] → ancho del plano en píxeles (para escala).
///   [altoPlanoPx]  → alto del plano en píxeles (para escala).
class CapturaPage extends StatefulWidget {
  final int planoId;
  final String imagenUrl;
  final double anchoPlanoPx;
  final double altoPlanoPx;

  const CapturaPage({
    super.key,
    required this.planoId,
    required this.imagenUrl,
    required this.anchoPlanoPx,
    required this.altoPlanoPx,
  });

  @override
  State<CapturaPage> createState() => _CapturaPageState();
}

class _CapturaPageState extends State<CapturaPage> {
  final GlobalKey _canvasKey = GlobalKey();

  /// Controlador del InteractiveViewer para zoom/pan.
  final TransformationController _transformController =
      TransformationController();

  // Modo continuo
  Timer? _timerContinuo;

  /// Timer de 1 segundo para actualizar el countdown en la barra de estado.
  Timer? _timerContador;

  /// Segundos restantes para la próxima lectura (mostrado en la barra).
  int _segundosRestantesCiclo = 0;

  /// Número de lecturas acumuladas en el punto activo (empieza en 1 al crear).
  int _lecturasPuntoActivo = 0;

  /// ID del punto activo en modo continuo (al que se acumulan mediciones).
  int? _puntoActivoContinuoId;

  /// IDs de puntos antes del último tap en modo continuo.
  /// Permite detectar qué punto nuevo fue creado.
  Set<int> _puntosIdAntes = {};

  /// Indica que se espera la confirmación de un nuevo punto en modo continuo.
  bool _esperandoNuevoPuntoContinuo = false;

  @override
  void initState() {
    super.initState();
    context.read<CapturaCubit>().iniciarSesion(widget.planoId);
  }

  @override
  void dispose() {
    _timerContinuo?.cancel();
    _timerContador?.cancel();
    _transformController.dispose();
    super.dispose();
  }

  // ── Dimensiones del plano ──────────────────────────────────────────────────

  Size get _tamanoPlano => Size(widget.anchoPlanoPx, widget.altoPlanoPx);

  // ── Conversión coordenadas ─────────────────────────────────────────────────

  /// Convierte un tap en el widget canvas a coordenadas del plano.
  ///
  /// [tapLocal] es el [localPosition] del GestureDetector, que Flutter ya
  /// entrega en el espacio de contenido (pre-transformación del InteractiveViewer).
  /// No se aplica compensación manual adicional.
  Offset? _tapACoordenadasPlano(Offset tapLocal) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final widgetSize = box.size;

    return PlanoPuntosPainter.pantallaToPlanoCoordenadas(
      tapOffset: tapLocal,
      canvasSize: widgetSize,
      tamanoPlano: _tamanoPlano,
    );
  }

  // ── Handlers de gestos ─────────────────────────────────────────────────────

  void _onTap(TapUpDetails details, List<PuntoMedicion> puntos) {
    final posPlano = _tapACoordenadasPlano(details.localPosition);
    if (posPlano == null) return;

    // Verificar si tocó un punto existente
    final puntoTocado = PlanoPuntosPainter.puntoEnPosicion(
      posPlano: posPlano,
      puntos: puntos,
    );

    if (puntoTocado != null) {
      _abrirDetalle(puntoTocado);
    } else {
      // Bloquear marcado de nuevos puntos mientras el ciclo continuo está activo.
      // El técnico debe tocar ⊙ para detener antes de cambiar de posición.
      if (_puntoActivoContinuoId != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Detén las lecturas continuas (⊙) antes de marcar una nueva posición.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        return;
      }
      final cubitState = context.read<CapturaCubit>().state;
      final enModoContinuo = switch (cubitState) {
        CapturaActiva(:final modosContinuo) => modosContinuo,
        CapturaPuntoDetalle(:final modosContinuo) => modosContinuo,
        _ => false,
      };

      if (enModoContinuo) {
        // Detener timers del punto anterior antes de crear uno nuevo
        _timerContinuo?.cancel();
        _timerContador?.cancel();
        _timerContinuo = null;
        _timerContador = null;
        _puntosIdAntes = puntos.map((p) => p.id).toSet();
        setState(() {
          _puntoActivoContinuoId = null;
          _esperandoNuevoPuntoContinuo = true;
          _segundosRestantesCiclo = 0;
          _lecturasPuntoActivo = 0;
        });
      }

      context.read<CapturaCubit>().marcarPunto(
            posX: posPlano.dx,
            posY: posPlano.dy,
          );
    }
  }

  void _abrirDetalle(PuntoMedicion punto) {
    final cubit = context.read<CapturaCubit>();
    cubit.abrirDetallePunto(punto.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: PuntoDetalleSheet(punto: punto, cubit: cubit),
      ),
    ).then((_) {
      if (cubit.state is CapturaPuntoDetalle) {
        cubit.cerrarDetalle();
      }
    });
  }

  // ── Modo continuo ──────────────────────────────────────────────────────────

  void _iniciarTimerContinuo(int intervaloSeg) {
    _timerContinuo?.cancel();
    _timerContador?.cancel();
    // Inicializar countdown al intervalo completo
    setState(() => _segundosRestantesCiclo = intervaloSeg);

    // Timer principal: dispara cada N segundos para acumular mediciones
    _timerContinuo = Timer.periodic(
      Duration(seconds: intervaloSeg),
      (_) {
        final puntoId = _puntoActivoContinuoId;
        if (puntoId != null && mounted) {
          setState(() {
            _lecturasPuntoActivo++;
            _segundosRestantesCiclo = intervaloSeg; // reiniciar countdown
          });
          context
              .read<CapturaCubit>()
              .agregarMedicionesAPunto(puntoId: puntoId);
        }
      },
    );

    // Timer de UI: decrementa el countdown cada segundo
    _timerContador = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _segundosRestantesCiclo > 0) {
        setState(() => _segundosRestantesCiclo--);
      }
    });
  }

  /// Detiene las lecturas continuas del punto activo sin salir del modo continuo.
  /// El técnico puede tocar en otra posición para iniciar un nuevo ciclo.
  void _detenerLecturasContinuas() {
    _timerContinuo?.cancel();
    _timerContador?.cancel();
    _timerContinuo = null;
    _timerContador = null;
    setState(() {
      _puntoActivoContinuoId = null;
      _esperandoNuevoPuntoContinuo = false;
      _segundosRestantesCiclo = 0;
      _lecturasPuntoActivo = 0;
    });
  }

  void _detenerModoContinuo() {
    _timerContinuo?.cancel();
    _timerContador?.cancel();
    _timerContinuo = null;
    _timerContador = null;
    setState(() {
      _puntoActivoContinuoId = null;
      _esperandoNuevoPuntoContinuo = false;
      _segundosRestantesCiclo = 0;
      _lecturasPuntoActivo = 0;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CapturaCubit, CapturaState>(
      listenWhen: (prev, curr) =>
          // Modo continuo: detectar nuevo punto solo cuando se espera confirmación.
          (curr is CapturaActiva && _esperandoNuevoPuntoContinuo) ||
          // Errores: siempre notificar al técnico.
          curr is CapturaError ||
          // Throttling: solo al ENTRAR al estado (no en cada tap repetido).
          (curr is CapturaThrottling && prev is! CapturaThrottling) ||
          // Sin red: solo al ENTRAR al estado pausado.
          (curr is CapturaPausada && prev is! CapturaPausada),
      listener: (context, state) {
        if (state is CapturaActiva && _esperandoNuevoPuntoContinuo) {
          // Detectar el punto nuevo creado en modo continuo comparando IDs
          final nuevosIds =
              state.puntos.map((p) => p.id).toSet().difference(_puntosIdAntes);
          if (nuevosIds.isNotEmpty && state.modosContinuo) {
            setState(() {
              _puntoActivoContinuoId = nuevosIds.first;
              _esperandoNuevoPuntoContinuo = false;
              _lecturasPuntoActivo = 1; // primera lectura = el tap inicial
            });
            _iniciarTimerContinuo(state.intervaloSegundos);
          } else {
            // Creación falló o modo cambiado; resetear bandera
            setState(() => _esperandoNuevoPuntoContinuo = false);
          }
        } else if (state is CapturaError) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(state.mensaje),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 5),
              ),
            );
          context.read<CapturaCubit>().reanudar();
        } else if (state is CapturaThrottling) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Límite de escaneos alcanzado. Espera ${state.segundosRestantes}s.',
                ),
                duration: const Duration(seconds: 5),
              ),
            );
        } else if (state is CapturaPausada) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content:
                    Text('Sin conexión. Verifica tu red e intenta de nuevo.'),
                duration: Duration(seconds: 5),
              ),
            );
        }
      },
      builder: (context, state) {
        final puntos = switch (state) {
          CapturaActiva(:final puntos) => puntos,
          CapturaEnviando(:final puntos) => puntos,
          CapturaThrottling(:final puntos) => puntos,
          CapturaPausada(:final puntos) => puntos,
          CapturaPuntoDetalle(:final puntos) => puntos,
          CapturaError(:final puntos) => puntos,
          _ => <PuntoMedicion>[],
        };

        final enviando = state is CapturaEnviando;
        final modoContinuo = switch (state) {
          CapturaActiva(:final modosContinuo) => modosContinuo,
          CapturaPuntoDetalle(:final modosContinuo) => modosContinuo,
          _ => false,
        };
        final intervalo = switch (state) {
          CapturaActiva(:final intervaloSegundos) => intervaloSegundos,
          CapturaPuntoDetalle(:final intervaloSegundos) => intervaloSegundos,
          _ => 30,
        };

        return Scaffold(
          appBar: AppBar(
            title: const Text('Captura WiFi'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(32),
              child: _BarraModo(
                modoContinuo: modoContinuo,
                intervalo: intervalo,
                puntoActivoContinuoId: _puntoActivoContinuoId,
                esperandoPunto: _esperandoNuevoPuntoContinuo,
                lecturas: _lecturasPuntoActivo,
                segundosRestantes: _segundosRestantesCiclo,
              ),
            ),
            actions: [
              // Botón visible únicamente cuando hay un ciclo continuo activo
              if (modoContinuo && _puntoActivoContinuoId != null)
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined),
                  tooltip: 'Detener lecturas continuas',
                  onPressed: _detenerLecturasContinuas,
                ),
              _ModoSelector(
                modoContinuo: modoContinuo,
                intervalo: intervalo,
                bloqueado: modoContinuo && _puntoActivoContinuoId != null,
                onChanged: (continuo, seg) {
                  context
                      .read<CapturaCubit>()
                      .cambiarModo(continuo: continuo, intervaloSegundos: seg);
                  if (!continuo) {
                    _detenerModoContinuo();
                  }
                  // Al activar modo continuo NO se inicia el timer todavía;
                  // comienza tras el primer tap sobre el plano.
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              // ── Mapa interactivo ──────────────────────────────────────────
              InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 5,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    // Ajustar el canvas al aspect ratio del plano para que
                    // el sistema de coordenadas del painter coincida exactamente
                    // con los píxeles de la imagen (sin letterboxing).
                    final aspect = _tamanoPlano.width / _tamanoPlano.height;
                    double w = constraints.maxWidth;
                    double h = w / aspect;
                    if (h > constraints.maxHeight) {
                      h = constraints.maxHeight;
                      w = h * aspect;
                    }
                    return Center(
                      child: SizedBox(
                        key: _canvasKey,
                        width: w,
                        height: h,
                        // GestureDetector dentro del SizedBox: localPosition
                        // queda en el espacio del canvas (0→w, 0→h), sin el
                        // offset que introduce el Center respecto al
                        // LayoutBuilder completo.
                        child: GestureDetector(
                          onTapUp: enviando ? null : (d) => _onTap(d, puntos),
                          child: CustomPaint(
                            foregroundPainter: PlanoPuntosPainter(
                              puntos: puntos,
                              tamanoPlano: _tamanoPlano,
                            ),
                            child: Image.network(
                              widget.imagenUrl,
                              fit: BoxFit.fill,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image, size: 64),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Indicador de envío ────────────────────────────────────────
              if (enviando)
                const Positioned(
                  top: AppSpacing.md,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Text('Escaneando y enviando…'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Leyenda ───────────────────────────────────────────────────
              const Positioned(
                bottom: AppSpacing.lg,
                right: AppSpacing.md,
                child: _Leyenda(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Selector de modo ─────────────────────────────────────────────────────────

class _ModoSelector extends StatelessWidget {
  final bool modoContinuo;
  final int intervalo;
  final bool bloqueado;
  final void Function(bool continuo, int seg) onChanged;

  const _ModoSelector({
    required this.modoContinuo,
    required this.intervalo,
    required this.bloqueado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !bloqueado,
      icon: Icon(
        modoContinuo ? Icons.timer : Icons.touch_app,
        semanticLabel: modoContinuo ? 'Modo continuo' : 'Modo puntual',
      ),
      tooltip: bloqueado
          ? 'Detén las lecturas continuas (⊙) para cambiar de modo'
          : modoContinuo
              ? 'Modo continuo (${intervalo}s) — toca para cambiar'
              : 'Modo puntual — toca para cambiar',
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'puntual', child: Text('Modo puntual')),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'continuo_15',
          child: Text('Modo continuo — 15 s'),
        ),
        const PopupMenuItem(
          value: 'continuo_30',
          child: Text('Modo continuo — 30 s'),
        ),
        const PopupMenuItem(
          value: 'continuo_60',
          child: Text('Modo continuo — 60 s'),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'puntual':
            onChanged(false, 30);
          case 'continuo_15':
            onChanged(true, 15);
          case 'continuo_30':
            onChanged(true, 30);
          case 'continuo_60':
            onChanged(true, 60);
        }
      },
    );
  }
}

// ── Barra de estado de modo ─────────────────────────────────────────────────────

/// Barra decorativa en el `bottom` del AppBar que muestra el modo activo.
/// En modo continuo muestra el intervalo, el contador de lecturas y el
/// countdown hasta la próxima lectura.
class _BarraModo extends StatelessWidget {
  final bool modoContinuo;
  final int intervalo;
  final int? puntoActivoContinuoId;
  final bool esperandoPunto;
  final int lecturas;
  final int segundosRestantes;

  const _BarraModo({
    required this.modoContinuo,
    required this.intervalo,
    required this.puntoActivoContinuoId,
    required this.esperandoPunto,
    required this.lecturas,
    required this.segundosRestantes,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (!modoContinuo) {
      return _barraContenedor(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 14, color: cs.onSurface),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Modo puntual',
              style: tt.labelSmall?.copyWith(color: cs.onSurface),
            ),
          ],
        ),
      );
    }

    // ── Modo continuo ──
    final onC = cs.onPrimaryContainer;
    final labelBold =
        tt.labelSmall?.copyWith(color: onC, fontWeight: FontWeight.w600);
    final labelNormal = tt.labelSmall?.copyWith(color: onC);

    return _barraContenedor(
      color: cs.primaryContainer.withValues(alpha: 0.92),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BarraChip(
            icon: Icons.timer_outlined,
            label: 'Continuo · ${intervalo}s',
            style: labelBold,
            iconColor: onC,
          ),
          if (esperandoPunto)
            _BarraChip(
              icon: Icons.hourglass_empty,
              label: 'Creando punto…',
              style: labelNormal,
              iconColor: onC,
            )
          else if (puntoActivoContinuoId != null) ...[
            _BarraChip(
              icon: Icons.wifi_find,
              label: '$lecturas lectura${lecturas != 1 ? 's' : ''}',
              style: labelNormal,
              iconColor: onC,
            ),
            _BarraChip(
              icon: Icons.schedule,
              label: 'Próxima en ${segundosRestantes}s',
              style: labelNormal,
              iconColor: onC,
            ),
          ] else
            _BarraChip(
              icon: Icons.ads_click,
              label: 'Toca para iniciar',
              style: labelNormal,
              iconColor: onC,
            ),
        ],
      ),
    );
  }

  Widget _barraContenedor({required Color color, required Widget child}) =>
      Container(
        height: 32,
        width: double.infinity,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.center,
        child: child,
      );
}

class _BarraChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextStyle? style;
  final Color iconColor;

  const _BarraChip({
    required this.icon,
    required this.label,
    required this.style,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 3),
          Text(label, style: style),
        ],
      );
}

// ── Leyenda de niveles de señal ───────────────────────────────────────────────

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            _LeyendaItem(color: Color(0xFF27AE60), label: '≥ −70 dBm'),
            _LeyendaItem(color: Color(0xFFF1C40F), label: '−70..−80 dBm'),
            _LeyendaItem(color: Color(0xFFE67E22), label: '−80..−85 dBm'),
            _LeyendaItem(color: Color(0xFFE74C3C), label: '−85..−90 dBm'),
            _LeyendaItem(color: Color(0xFF1C1C1C), label: '< −90 dBm'),
          ],
        ),
      ),
    );
  }
}

class _LeyendaItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LeyendaItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
