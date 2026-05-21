import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';

import '../../domain/entities/plano.dart';
import '../cubit/planos_cubit.dart';
import '../cubit/planos_state.dart';

/// Página de listado de planos de un proyecto. PB-02 + entrada a PB-11.
class PlanosListPage extends StatefulWidget {
  final int proyectoId;
  final String? proyectoNombre;

  const PlanosListPage({
    super.key,
    required this.proyectoId,
    this.proyectoNombre,
  });

  @override
  State<PlanosListPage> createState() => _PlanosListPageState();
}

class _PlanosListPageState extends State<PlanosListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanosCubit>().cargarPlanos(widget.proyectoId);
    });
  }

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (!mounted) return;
    if (file.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo acceder al archivo. '
            'Intenta copiarlo al almacenamiento interno del dispositivo e inténtalo de nuevo.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Vista previa PDF antes de subir (Sp2-08 / PB-02).
    if (file.path!.toLowerCase().endsWith('.pdf')) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => _PdfPreviewDialog(
          ruta: file.path!,
          nombre: file.name,
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    await context.read<PlanosCubit>().importarPlano(
          rutaArchivo: file.path!,
          nombre: file.name,
        );
  }

  Future<void> _confirmarEliminar(Plano plano) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar plano'),
        content: Text(
          '¿Seguro que deseas eliminar "${plano.nombre}"? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await context.read<PlanosCubit>().eliminarPlano(plano.id);
    }
  }

  void _abrirEditor(Plano plano) {
    context.pushNamed(
      'plano-editor',
      pathParameters: {
        'id': widget.proyectoId.toString(),
        'planoId': plano.id.toString(),
      },
      extra: {
        'cubit': context.read<PlanosCubit>(),
        'plano': plano,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.proyectoNombre != null
            ? 'Planos · ${widget.proyectoNombre}'
            : 'Planos del proyecto'),
      ),
      body: BlocConsumer<PlanosCubit, PlanosState>(
        listener: (context, state) {
          if (state is PlanosOperacionExitosa) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.mensaje)),
            );
          } else if (state is PlanosError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.mensaje),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is PlanosLoading && state is! PlanosListaExitosa) {
            return const Center(child: CircularProgressIndicator());
          }
          final planos = switch (state) {
            PlanosListaExitosa(:final planos) => planos,
            PlanosOperacionExitosa(:final planos) => planos,
            PlanosError(:final planos) => planos,
            _ => const <Plano>[],
          };
          if (planos.isEmpty) {
            return _EmptyState(onImport: _seleccionarArchivo);
          }
          return RefreshIndicator(
            onRefresh: () =>
                context.read<PlanosCubit>().cargarPlanos(widget.proyectoId),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: planos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final plano = planos[index];
                return _PlanoCard(
                  plano: plano,
                  onTap: () => _abrirEditor(plano),
                  onEliminar: () => _confirmarEliminar(plano),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _seleccionarArchivo,
        icon: const Icon(Icons.upload_file),
        label: const Text('Importar plano'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onImport;
  const _EmptyState({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 96, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Aún no hay planos en este proyecto.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Importa un plano arquitectónico (PNG, JPG o PDF, máx. 20 MB) '
              'para comenzar a calibrar y registrar mediciones.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('Importar primer plano'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanoCard extends StatelessWidget {
  final Plano plano;
  final VoidCallback onTap;
  final VoidCallback onEliminar;
  const _PlanoCard({
    required this.plano,
    required this.onTap,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tamanoMb = (plano.tamanoBytes / 1024 / 1024).toStringAsFixed(2);
    final dimensiones = '${plano.anchoPx} × ${plano.altoPx} px';
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: tema.colorScheme.primaryContainer,
          child: Icon(
            plano.formato == FormatoPlano.pdf
                ? Icons.picture_as_pdf
                : Icons.image,
            color: tema.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          plano.nombre,
          style: tema.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${plano.formato.etiqueta} · $tamanoMb MB · $dimensiones'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  plano.calibrado ? Icons.check_circle : Icons.warning_amber,
                  size: 16,
                  color: plano.calibrado ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  plano.calibrado
                      ? 'Calibrado · ${plano.escalaMPorPx!.toStringAsFixed(4)} m/px'
                      : 'Sin calibrar',
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Eliminar',
          onPressed: onEliminar,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Diálogo de vista previa de PDF local antes de importarlo al backend.
/// Usa `pdfx` para renderizar la primera página. Sp2-08 / PB-02.
class _PdfPreviewDialog extends StatefulWidget {
  final String ruta;
  final String nombre;

  const _PdfPreviewDialog({required this.ruta, required this.nombre});

  @override
  State<_PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends State<_PdfPreviewDialog> {
  late final PdfController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfController(
      document: PdfDocument.openFile(widget.ruta),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Vista previa del PDF'),
          Text(
            widget.nombre,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: PdfView(
          controller: _controller,
          scrollDirection: Axis.vertical,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Importar'),
        ),
      ],
    );
  }
}
