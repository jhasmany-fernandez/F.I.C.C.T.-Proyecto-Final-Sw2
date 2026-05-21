import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_loading_button.dart';
import '../../../clientes/data/datasources/cliente_remote_datasource.dart';
import '../../domain/entities/proyecto.dart';
import '../bloc/proyecto_cubit.dart';
import '../bloc/proyecto_state.dart';

/// Pantalla para crear o editar un proyecto de survey.
/// Si [proyectoExistente] es null → modo creación.
/// Si [proyectoExistente] no es null → modo edición.
/// CA-1 y CA-2 PB-01 — Sp-13
class ProyectoFormPage extends StatefulWidget {
  final Proyecto? proyectoExistente;

  const ProyectoFormPage({super.key, this.proyectoExistente});

  @override
  State<ProyectoFormPage> createState() => _ProyectoFormPageState();
}

class _ProyectoFormPageState extends State<ProyectoFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;

  int? _clienteSeleccionadoId;
  late Future<List<ClienteItem>> _clientesFuture;

  bool get _esEdicion => widget.proyectoExistente != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
      text: widget.proyectoExistente?.nombre ?? '',
    );
    _descripcionCtrl = TextEditingController(
      text: widget.proyectoExistente?.descripcion ?? '',
    );
    _clienteSeleccionadoId = widget.proyectoExistente?.clienteId;
    _clientesFuture = GetIt.instance<ClienteRemoteDatasource>().listarActivos();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<ProyectoCubit>();
    final descripcion = _descripcionCtrl.text.trim();

    if (_esEdicion) {
      cubit.actualizarProyecto(
        id: widget.proyectoExistente!.id,
        nombre: _nombreCtrl.text.trim(),
        clienteId: _clienteSeleccionadoId,
        descripcion: descripcion.isEmpty ? null : descripcion,
      );
    } else {
      cubit.crearProyecto(
        nombre: _nombreCtrl.text.trim(),
        clienteId: _clienteSeleccionadoId,
        descripcion: descripcion.isEmpty ? null : descripcion,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar proyecto' : 'Nuevo proyecto'),
        centerTitle: false,
      ),
      body: BlocListener<ProyectoCubit, ProyectoState>(
        listener: (context, state) {
          if (state is ProyectoOperacionExitosa) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.mensaje),
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.pop();
          }
          if (state is ProyectoError) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.mensaje),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ));
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nombreCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del proyecto *',
                    hintText: 'Ej: Edificio Torre Norte',
                    prefixIcon: Icon(Icons.folder_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                FutureBuilder<List<ClienteItem>>(
                  future: _clientesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    final clientes = snapshot.data ?? [];
                    return DropdownButtonFormField<int?>(
                      initialValue: _clienteSeleccionadoId,
                      decoration: const InputDecoration(
                        labelText: 'Cliente',
                        hintText: 'Seleccionar cliente (opcional)',
                        prefixIcon: Icon(Icons.business_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sin cliente'),
                        ),
                        ...clientes.map(
                          (c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.nombre),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _clienteSeleccionadoId = val),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descripcionCtrl,
                  textInputAction: TextInputAction.done,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintText: 'Detalle del relevamiento o ubicación',
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                BlocBuilder<ProyectoCubit, ProyectoState>(
                  builder: (context, state) {
                    final cargando = state is ProyectoLoading;
                    return AppLoadingButton(
                      label: _esEdicion ? 'Guardar cambios' : 'Crear proyecto',
                      isLoading: cargando,
                      onPressed: cargando ? null : _guardar,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
