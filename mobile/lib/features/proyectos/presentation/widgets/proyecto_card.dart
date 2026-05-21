import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_estado_badge.dart';
import '../../domain/entities/proyecto.dart';

/// Card de un proyecto en la lista principal.
/// Muestra: nombre, cliente, estado (badge de color), fecha última actividad.
/// HU PB-01 / PB-10 — Sp-13
class ProyectoCard extends StatelessWidget {
  final Proyecto proyecto;
  final VoidCallback onTap;
  final VoidCallback onArchivar;
  final VoidCallback onEliminar;

  const ProyectoCard({
    super.key,
    required this.proyecto,
    required this.onTap,
    required this.onArchivar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: const Icon(Icons.wifi_find_rounded),
        ),
        title: Text(
          proyecto.nombre,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              proyecto.cliente,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                AppEstadoBadge(estado: proyecto.estado),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _formatearFecha(proyecto.updatedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<_AccionProyecto>(
          tooltip: 'Opciones',
          onSelected: (accion) {
            switch (accion) {
              case _AccionProyecto.archivar:
                onArchivar();
              case _AccionProyecto.eliminar:
                onEliminar();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: _AccionProyecto.archivar,
              child: ListTile(
                leading: Icon(Icons.archive_outlined),
                title: Text('Archivar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _AccionProyecto.eliminar,
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: scheme.error),
                title: Text(
                  'Eliminar',
                  style: TextStyle(color: scheme.error),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }
}

enum _AccionProyecto { archivar, eliminar }
