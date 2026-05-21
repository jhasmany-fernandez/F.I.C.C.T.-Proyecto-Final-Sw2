import 'package:flutter/material.dart';

import '../../features/proyectos/domain/entities/proyecto.dart';

/// Tokens de diseño centralizados.
///
/// Toda nueva pantalla/widget DEBE consumir estos tokens en lugar de
/// hardcodear valores. Ver `.github/instructions/mobile-design.instructions.md`.

/// Color semilla del producto Wireless HeatMapper.
const Color kSeedColor = Color(0xFF2980B9);

/// Espaciado base (múltiplos de 4 px).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;
}

/// Radios de borde estandarizados.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// Helpers de paleta semántica.
abstract final class AppPalette {
  /// Color sólido para el estado de un proyecto. Derivado del [ColorScheme]
  /// activo para soportar dark mode automáticamente.
  static Color estadoColor(BuildContext context, EstadoProyecto estado) {
    final scheme = Theme.of(context).colorScheme;
    return switch (estado) {
      EstadoProyecto.nuevo => scheme.primary,
      EstadoProyecto.enProgreso => scheme.tertiary,
      EstadoProyecto.completado => scheme.secondary,
      EstadoProyecto.archivado => scheme.outline,
    };
  }
}
