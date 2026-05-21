import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Cabecera de marca: logo de Bulldog Tech + nombre del producto + cliente.
///
/// Se reutiliza en pantallas de entrada (login, splash). El logo se aplica
/// con [ColorFiltered] para invertir el monograma según el brillo del tema,
/// garantizando contraste correcto en dark mode.
class AppBrandingHeader extends StatelessWidget {
  /// Tamaño del lado del logo (cuadrado).
  final double logoSize;

  /// Mostrar el subtítulo "Bulldog Tech.".
  final bool mostrarCliente;

  const AppBrandingHeader({
    super.key,
    this.logoSize = 96,
    this.mostrarCliente = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final esOscuro = theme.brightness == Brightness.dark;

    // En dark mode invertimos el logo (negro -> claro) para que contraste.
    final logo = Image.asset(
      'img/logo.png',
      width: logoSize,
      height: logoSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: esOscuro
              ? ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    -1, 0, 0, 0, 255, //
                    0, -1, 0, 0, 255, //
                    0, 0, -1, 0, 255, //
                    0, 0, 0, 1, 0,
                  ]),
                  child: logo,
                )
              : logo,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Wireless HeatMapper',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        if (mostrarCliente) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bulldog Tech.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }
}
