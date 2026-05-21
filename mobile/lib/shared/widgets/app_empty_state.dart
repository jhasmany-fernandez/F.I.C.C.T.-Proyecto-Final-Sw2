import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Estado vacío reutilizable: ícono + mensaje + acción opcional.
class AppEmptyState extends StatelessWidget {
  final IconData icono;
  final String mensaje;
  final String? accionLabel;
  final IconData? accionIcono;
  final VoidCallback? onAccion;

  const AppEmptyState({
    super.key,
    required this.icono,
    required this.mensaje,
    this.accionLabel,
    this.accionIcono,
    this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: scheme.outline),
            const SizedBox(height: AppSpacing.md),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (accionLabel != null && onAccion != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onAccion,
                icon: Icon(accionIcono ?? Icons.add),
                label: Text(accionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
