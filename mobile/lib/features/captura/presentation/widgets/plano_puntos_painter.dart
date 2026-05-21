import 'package:flutter/material.dart';

import '../../domain/entities/nivel_senal.dart';
import '../../domain/entities/punto_medicion.dart';

/// Painter de Flutter Canvas que dibuja los puntos de medición sobre el plano.
/// Sprint 3 — PB-04 (Sp3-19).
///
/// Cada punto se renderiza como un círculo con color según el [NivelSenal]:
///   verde    → verde vibrante
///   amarillo → amarillo
///   naranja  → naranja
///   rojo     → rojo
///   negro    → negro / zona muerta
class PlanoPuntosPainter extends CustomPainter {
  final List<PuntoMedicion> puntos;
  final int? puntoSeleccionadoId;
  final Size tamanoPlano;

  static const Map<NivelSenal, Color> _colores = {
    NivelSenal.verde: Color(0xFF27AE60),
    NivelSenal.amarillo: Color(0xFFF1C40F),
    NivelSenal.naranja: Color(0xFFE67E22),
    NivelSenal.rojo: Color(0xFFE74C3C),
    NivelSenal.negro: Color(0xFF1C1C1C),
  };

  const PlanoPuntosPainter({
    required this.puntos,
    required this.tamanoPlano,
    this.puntoSeleccionadoId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tamanoPlano.isEmpty) return;

    final scaleX = size.width / tamanoPlano.width;
    final scaleY = size.height / tamanoPlano.height;

    for (final punto in puntos) {
      final cx = punto.posX * scaleX;
      final cy = punto.posY * scaleY;

      final color = _colores[punto.nivel] ?? Colors.grey;
      final seleccionado = punto.id == puntoSeleccionadoId;
      final radio = seleccionado ? 14.0 : 10.0;

      // Sombra
      canvas.drawCircle(
        Offset(cx + 1, cy + 1),
        radio + 1,
        Paint()..color = Colors.black26,
      );

      // Relleno
      canvas.drawCircle(
        Offset(cx, cy),
        radio,
        Paint()..color = color,
      );

      // Borde blanco
      canvas.drawCircle(
        Offset(cx, cy),
        radio,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = seleccionado ? 3 : 2,
      );
    }
  }

  @override
  bool shouldRepaint(PlanoPuntosPainter oldDelegate) =>
      oldDelegate.puntos != puntos ||
      oldDelegate.puntoSeleccionadoId != puntoSeleccionadoId ||
      oldDelegate.tamanoPlano != tamanoPlano;

  /// Convierte coordenadas de pantalla en coordenadas del plano.
  /// [tapOffset] es la posición del toque en el widget canvas.
  /// [canvasSize] es el tamaño actual del widget Canvas.
  static Offset pantallaToPlanoCoordenadas({
    required Offset tapOffset,
    required Size canvasSize,
    required Size tamanoPlano,
  }) {
    if (canvasSize.isEmpty || tamanoPlano.isEmpty) return tapOffset;
    final scaleX = tamanoPlano.width / canvasSize.width;
    final scaleY = tamanoPlano.height / canvasSize.height;
    return Offset(
      (tapOffset.dx * scaleX).clamp(0, tamanoPlano.width),
      (tapOffset.dy * scaleY).clamp(0, tamanoPlano.height),
    );
  }

  /// Retorna el [PuntoMedicion] más cercano al toque en coordenadas del plano,
  /// o `null` si ninguno está a menos de [radioTolerancia] píxeles del plano.
  static PuntoMedicion? puntoEnPosicion({
    required Offset posPlano,
    required List<PuntoMedicion> puntos,
    double radioTolerancia = 20,
  }) {
    PuntoMedicion? cercano;
    double minDist = radioTolerancia;
    for (final p in puntos) {
      final dist = (Offset(p.posX, p.posY) - posPlano).distance;
      if (dist < minDist) {
        minDist = dist;
        cercano = p;
      }
    }
    return cercano;
  }
}
