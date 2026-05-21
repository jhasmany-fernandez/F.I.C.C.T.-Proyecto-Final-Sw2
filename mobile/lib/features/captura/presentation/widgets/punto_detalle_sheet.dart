import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/medicion_wifi.dart';
import '../../domain/entities/nivel_senal.dart';
import '../../domain/entities/punto_medicion.dart';
import '../cubit/captura_cubit.dart';
import '../cubit/captura_state.dart';

/// Bottom sheet que muestra el detalle de un punto de medición.
/// Sprint 3 — PB-04 CA-4 (Sp3-20).
///
/// Muestra:
///   - Posición del punto (píxeles del plano).
///   - Nivel de señal agregado.
///   - Lista de mediciones WiFi ordenadas por RSSI (mayor primero).
///   - Botón de eliminar con diálogo de confirmación.
class PuntoDetalleSheet extends StatelessWidget {
  final PuntoMedicion punto;
  final CapturaCubit cubit;

  const PuntoDetalleSheet({
    super.key,
    required this.punto,
    required this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<CapturaCubit, CapturaState>(
      builder: (context, state) {
        // El cubit carga el detalle completo del punto de forma asíncrona y
        // emite CapturaPuntoDetalle con mediciones. Mientras llega, se muestra
        // el punto local (sin mediciones) con un indicador de carga.
        final puntoDetalle =
            state is CapturaPuntoDetalle ? state.puntoSeleccionado : null;
        final mediciones = puntoDetalle?.mediciones ?? const [];
        final cargando = puntoDetalle == null;
        final puntoDisplay = puntoDetalle ?? punto;

        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollCtrl) {
            return Column(
              children: [
                // Asa de arrastre
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                // Cabecera
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      _NivelBadge(nivel: puntoDisplay.nivel),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Punto #${puntoDisplay.id} — (${puntoDisplay.posX.toStringAsFixed(0)}, ${puntoDisplay.posY.toStringAsFixed(0)} px)',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: theme.colorScheme.error,
                        tooltip: 'Eliminar punto',
                        onPressed: () => _confirmarEliminar(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Lista de mediciones agrupadas por número de lectura
                Expanded(
                  child: cargando
                      ? const Center(child: CircularProgressIndicator())
                      : mediciones.isEmpty
                          ? Center(
                              child: Text(
                                'Sin mediciones en este punto.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          : _ListaMedicionesAgrupadas(
                              scrollCtrl: scrollCtrl,
                              mediciones: mediciones,
                              theme: theme,
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar punto'),
        content: const Text(
          '¿Eliminar este punto y todas sus mediciones? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await cubit.eliminarPunto(punto.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  static Color _colorPorNivel(NivelSenal nivel, ThemeData theme) =>
      switch (nivel) {
        NivelSenal.verde => const Color(0xFF27AE60),
        NivelSenal.amarillo => const Color(0xFFD4A017),
        NivelSenal.naranja => const Color(0xFFE67E22),
        NivelSenal.rojo => theme.colorScheme.error,
        NivelSenal.negro => theme.colorScheme.onSurface,
      };
}

// ---------------------------------------------------------------------------
// Lista agrupada por número de lectura
// ---------------------------------------------------------------------------

class _ListaMedicionesAgrupadas extends StatelessWidget {
  final ScrollController scrollCtrl;
  final List<MedicionWifi> mediciones;
  final ThemeData theme;

  const _ListaMedicionesAgrupadas({
    required this.scrollCtrl,
    required this.mediciones,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Agrupar por numero_lectura manteniendo el orden del backend
    final grupos = <int, List<MedicionWifi>>{};
    for (final m in mediciones) {
      (grupos[m.numeroLectura] ??= []).add(m);
    }
    final lecturas = grupos.keys.toList()..sort();

    // Construir lista plana: [header, item, item, ..., header, item, ...]
    final filas = <Widget>[];
    for (final lectura in lecturas) {
      final items = grupos[lectura]!;
      filas.add(_LecturaHeader(numero: lectura, total: items.length));
      for (int i = 0; i < items.length; i++) {
        final m = items[i];
        filas.add(
          ListTile(
            dense: true,
            leading: _NivelBadge(nivel: m.nivel, small: true),
            title: Text(
              m.ssid.isEmpty ? '(oculta)' : m.ssid,
              style: theme.textTheme.bodyMedium,
            ),
            subtitle: Text(
              m.bssid,
              style: theme.textTheme.bodySmall,
            ),
            trailing: Text(
              '${m.rssi} dBm',
              style: theme.textTheme.labelMedium?.copyWith(
                color: PuntoDetalleSheet._colorPorNivel(m.nivel, theme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        if (i < items.length - 1) {
          filas.add(const Divider(height: 1, indent: AppSpacing.md));
        }
      }
      filas.add(const Divider(height: 8, thickness: 0));
    }

    return ListView(
      controller: scrollCtrl,
      children: filas,
    );
  }
}

class _LecturaHeader extends StatelessWidget {
  final int numero;
  final int total;

  const _LecturaHeader({required this.numero, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(180),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      child: Row(
        children: [
          Text(
            'Lectura #$numero',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '· $total red${total == 1 ? '' : 'es'} detectada${total == 1 ? '' : 's'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NivelBadge extends StatelessWidget {
  final NivelSenal nivel;
  final bool small;

  const _NivelBadge({required this.nivel, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = switch (nivel) {
      NivelSenal.verde => const Color(0xFF27AE60),
      NivelSenal.amarillo => const Color(0xFFF1C40F),
      NivelSenal.naranja => const Color(0xFFE67E22),
      NivelSenal.rojo => const Color(0xFFE74C3C),
      NivelSenal.negro => const Color(0xFF1C1C1C),
    };
    final label = switch (nivel) {
      NivelSenal.verde => 'Óptimo',
      NivelSenal.amarillo => 'Aceptable',
      NivelSenal.naranja => 'Pobre',
      NivelSenal.rojo => 'Muy pobre',
      NivelSenal.negro => 'Zona muerta',
    };
    final size = small ? 10.0 : 12.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : AppSpacing.sm,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
