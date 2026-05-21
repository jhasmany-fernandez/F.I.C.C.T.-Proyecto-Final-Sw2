import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Banner persistente de "Sin conexión" — usa tokens del tema, soporta dark.
class AppConnectionBanner extends StatelessWidget {
  final String mensaje;

  const AppConnectionBanner({
    super.key,
    this.mensaje = 'Sin conexión. Verifique su conexión a internet.',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded,
              color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              mensaje,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
