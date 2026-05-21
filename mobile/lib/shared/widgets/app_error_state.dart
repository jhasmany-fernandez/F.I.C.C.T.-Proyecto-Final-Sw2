import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Estado de error reutilizable con botón de "Reintentar".
class AppErrorState extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  final IconData icono;

  const AppErrorState({
    super.key,
    required this.mensaje,
    required this.onReintentar,
    this.icono = Icons.cloud_off_outlined,
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
            Icon(icono, size: 56, color: scheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
