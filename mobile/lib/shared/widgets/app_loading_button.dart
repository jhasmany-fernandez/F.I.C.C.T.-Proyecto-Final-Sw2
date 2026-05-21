import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Botón primario con estado de carga integrado.
///
/// Reemplaza el patrón duplicado de `FilledButton` + `CircularProgressIndicator`
/// interno. Ver `.github/instructions/mobile-design.instructions.md`.
class AppLoadingButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool enabled;
  final VoidCallback? onPressed;

  const AppLoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final efectivoOnPressed = (isLoading || !enabled) ? null : onPressed;

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: scheme.onPrimary,
            ),
          )
        : (icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(label),
                ],
              ));

    return FilledButton(
      onPressed: efectivoOnPressed,
      child: child,
    );
  }
}
