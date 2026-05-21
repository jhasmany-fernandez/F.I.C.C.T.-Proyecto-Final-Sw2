import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../main.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/proyecto_cubit.dart';
import '../bloc/proyecto_state.dart';
import '../widgets/proyecto_card.dart';

/// Pantalla principal de la lista de proyectos activos.
/// CA-1, CA-2, CA-3, CA-4, CA-5 PB-01 / CA-1..CA-5 PB-10.
/// HU PB-01 — Sp-13
class ProyectosPage extends StatefulWidget {
  const ProyectosPage({super.key});

  @override
  State<ProyectosPage> createState() => _ProyectosPageState();
}

class _ProyectosPageState extends State<ProyectosPage> {
  static const _debounceMs = 300;

  final _busquedaCtrl = TextEditingController();
  Timer? _debounce;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    context.read<ProyectoCubit>().cargarProyectos();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  void _onBusquedaChanged(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      if (!mounted) return;
      setState(() => _filtro = valor.trim().toLowerCase());
    });
  }

  Future<void> _confirmarLogout(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, size: 36),
        title: const Text('Cerrar sesión'),
        content: const Text('¿Desea cerrar la sesión actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar == true && context.mounted) {
      // Sp1 — fix CA-4: invocar AuthCubit.logout() para borrar el JWT del
      // SecureStorage. La navegación a /login la hace el listener.
      await sl<AuthCubit>().logout();
    }
  }

  Future<void> _confirmarArchivar(
      BuildContext context, int id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.archive_outlined, size: 36),
        title: const Text('Archivar proyecto'),
        content: Text(
            '¿Archivar "$nombre"? Podrás verlo en la sección de archivados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirmar == true && context.mounted) {
      context.read<ProyectoCubit>().archivarProyecto(id);
    }
  }

  Future<void> _confirmarEliminar(
      BuildContext context, int id, String nombre) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon:
            Icon(Icons.delete_forever_outlined, size: 36, color: scheme.error),
        title: const Text('Eliminar proyecto'),
        content: Text(
          'Esta acción eliminará todos los datos del proyecto "$nombre". ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true && context.mounted) {
      context.read<ProyectoCubit>().eliminarProyecto(id);
    }
  }

  void _mostrarSnackError(BuildContext context, String mensaje,
      {VoidCallback? onReintentar}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(mensaje),
        backgroundColor: scheme.error,
        action: onReintentar == null
            ? null
            : SnackBarAction(
                label: 'Reintentar',
                textColor: scheme.onError,
                onPressed: onReintentar,
              ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Proyectos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Cerrar sesión',
            onPressed: () => _confirmarLogout(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/proyectos/nuevo',
            extra: context.read<ProyectoCubit>()),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo proyecto'),
      ),
      body: MultiBlocListener(
        listeners: [
          // Reaccionar al logout: navegar a /login cuando AuthCubit
          // emite Unauthenticated tras llamar a logout().
          BlocListener<AuthCubit, AuthState>(
            bloc: sl<AuthCubit>(),
            listener: (context, state) {
              if (state is AuthUnauthenticated) {
                context.go('/login');
              }
              if (state is AuthError) {
                _mostrarSnackError(context, state.mensaje);
              }
            },
          ),
          BlocListener<ProyectoCubit, ProyectoState>(
            listener: (context, state) {
              if (state is ProyectoError) {
                _mostrarSnackError(
                  context,
                  state.mensaje,
                  onReintentar: () =>
                      context.read<ProyectoCubit>().cargarProyectos(),
                );
              }
              if (state is ProyectoEliminado) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Proyecto eliminado.')),
                );
                context.read<ProyectoCubit>().cargarProyectos();
              }
              if (state is ProyectoOperacionExitosa) {
                context.read<ProyectoCubit>().cargarProyectos();
              }
            },
          ),
        ],
        child: BlocBuilder<ProyectoCubit, ProyectoState>(
          builder: (context, state) {
            if (state is ProyectoLoading || state is ProyectoInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ProyectoListaExitosa) {
              final proyectosFiltrados = _filtro.isEmpty
                  ? state.proyectos
                  : state.proyectos
                      .where((p) =>
                          p.nombre.toLowerCase().contains(_filtro) ||
                          p.cliente.toLowerCase().contains(_filtro))
                      .toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm + 4,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: TextField(
                      controller: _busquedaCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar por proyecto o cliente…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _busquedaCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _busquedaCtrl.clear();
                                  _onBusquedaChanged('');
                                },
                              )
                            : null,
                      ),
                      onChanged: _onBusquedaChanged,
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          context.read<ProyectoCubit>().cargarProyectos(),
                      child: proyectosFiltrados.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: AppSpacing.xxxl),
                                AppEmptyState(
                                  icono: _filtro.isNotEmpty
                                      ? Icons.search_off
                                      : Icons.folder_off_outlined,
                                  mensaje: _filtro.isNotEmpty
                                      ? 'Sin resultados para la búsqueda.'
                                      : 'No hay proyectos. Crea tu primer survey.',
                                  accionLabel: _filtro.isNotEmpty
                                      ? null
                                      : 'Crear primer proyecto',
                                  accionIcono: Icons.add,
                                  onAccion: _filtro.isNotEmpty
                                      ? null
                                      : () => context.push(
                                            '/proyectos/nuevo',
                                            extra:
                                                context.read<ProyectoCubit>(),
                                          ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xxxl + AppSpacing.xxl,
                              ),
                              itemCount: proyectosFiltrados.length,
                              itemBuilder: (_, i) {
                                final proyecto = proyectosFiltrados[i];
                                return ProyectoCard(
                                  proyecto: proyecto,
                                  onTap: () => context.push(
                                    '/proyectos/${proyecto.id}',
                                    extra: {'proyectoNombre': proyecto.nombre},
                                  ),
                                  onArchivar: () => _confirmarArchivar(
                                    context,
                                    proyecto.id,
                                    proyecto.nombre,
                                  ),
                                  onEliminar: () => _confirmarEliminar(
                                    context,
                                    proyecto.id,
                                    proyecto.nombre,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              );
            }

            // ProyectoError sin lista previa o estado inesperado.
            return AppErrorState(
              mensaje: 'No se pudo cargar la lista de proyectos.',
              onReintentar: () =>
                  context.read<ProyectoCubit>().cargarProyectos(),
            );
          },
        ),
      ),
    );
  }
}
