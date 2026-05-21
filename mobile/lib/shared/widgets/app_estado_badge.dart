import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../features/proyectos/domain/entities/proyecto.dart';

/// Badge de color para el estado de un proyecto.
///
/// Usa [AppPalette.estadoColor] para mantener consistencia con el tema activo
/// (light + dark).
class AppEstadoBadge extends StatelessWidget {
  final EstadoProyecto estado;

  const AppEstadoBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.estadoColor(context, estado);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        estado.etiqueta,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
