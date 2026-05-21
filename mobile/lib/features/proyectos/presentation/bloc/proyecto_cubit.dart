import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/proyecto_repository.dart';
import '../../domain/usecases/obtener_proyectos_activos_usecase.dart';
import '../../domain/usecases/crear_proyecto_usecase.dart';
import '../../domain/usecases/actualizar_proyecto_usecase.dart';
import '../../domain/usecases/archivar_proyecto_usecase.dart';
import '../../domain/usecases/eliminar_proyecto_usecase.dart';
import 'proyecto_state.dart';

/// Cubit de gestión de proyectos de survey.
/// Expone operaciones CRUD + archivado y mantiene la lista reactiva.
/// HU PB-01 — Sp-12
class ProyectoCubit extends Cubit<ProyectoState> {
  final ObtenerProyectosActivosUseCase _obtenerActivos;
  final CrearProyectoUseCase _crear;
  final ActualizarProyectoUseCase _actualizar;
  final ArchivarProyectoUseCase _archivar;
  final EliminarProyectoUseCase _eliminar;

  ProyectoCubit({
    required ObtenerProyectosActivosUseCase obtenerActivos,
    required CrearProyectoUseCase crear,
    required ActualizarProyectoUseCase actualizar,
    required ArchivarProyectoUseCase archivar,
    required EliminarProyectoUseCase eliminar,
  })  : _obtenerActivos = obtenerActivos,
        _crear = crear,
        _actualizar = actualizar,
        _archivar = archivar,
        _eliminar = eliminar,
        super(const ProyectoInitial());

  /// Carga la lista de proyectos activos. Sp-12 / CA-1 PB-10.
  Future<void> cargarProyectos() async {
    emit(const ProyectoLoading());
    try {
      final proyectos = await _obtenerActivos();
      emit(ProyectoListaExitosa(proyectos));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Sesión expirada: el interceptor ya limpió los tokens y redirigió a /login.
        // No emitir error para no mostrar el SnackBar "No se pudo cargar...".
        return;
      }
      emit(const ProyectoError('No se pudo cargar la lista de proyectos.'));
    } catch (_) {
      emit(const ProyectoError('No se pudo cargar la lista de proyectos.'));
    }
  }

  /// Crea un proyecto nuevo. CA-1 PB-01.
  Future<void> crearProyecto({
    required String nombre,
    int? clienteId,
    String? descripcion,
  }) async {
    emit(const ProyectoLoading());
    try {
      final proyecto = await _crear(
        nombre: nombre,
        clienteId: clienteId,
        descripcion: descripcion,
      );
      emit(ProyectoOperacionExitosa(
        proyecto: proyecto,
        mensaje: 'Proyecto "${proyecto.nombre}" creado.',
      ));
    } on ProyectoNombreVacioException {
      emit(const ProyectoError('El nombre del proyecto no puede estar vacío.'));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return;
      emit(const ProyectoError('No se pudo crear el proyecto.'));
    } catch (_) {
      emit(const ProyectoError('No se pudo crear el proyecto.'));
    }
  }

  /// Actualiza datos de un proyecto existente. CA-2 PB-01.
  Future<void> actualizarProyecto({
    required int id,
    required String nombre,
    int? clienteId,
    String? descripcion,
  }) async {
    emit(const ProyectoLoading());
    try {
      final proyecto = await _actualizar(
        id: id,
        nombre: nombre,
        clienteId: clienteId,
        descripcion: descripcion,
      );
      emit(ProyectoOperacionExitosa(
        proyecto: proyecto,
        mensaje: 'Proyecto actualizado.',
      ));
    } on ProyectoNombreVacioException {
      emit(const ProyectoError('El nombre del proyecto no puede estar vacío.'));
    } on ProyectoNoEncontradoException {
      emit(const ProyectoError('El proyecto no existe.'));
    } catch (_) {
      emit(const ProyectoError('No se pudo actualizar el proyecto.'));
    }
  }

  /// Archiva un proyecto. CA-3 PB-01.
  Future<void> archivarProyecto(int id) async {
    emit(const ProyectoLoading());
    try {
      await _archivar(id);
      final proyectos = await _obtenerActivos();
      emit(ProyectoListaExitosa(proyectos));
    } on ProyectoNoEncontradoException {
      emit(const ProyectoError('El proyecto no existe.'));
    } catch (_) {
      emit(const ProyectoError('No se pudo archivar el proyecto.'));
    }
  }

  /// Elimina un proyecto (sin protección de reporte: la UI debe pedir confirmación).
  /// CA-4 y CA-5 PB-01: la UI muestra el diálogo de confirmación antes de llamar aquí.
  Future<void> eliminarProyecto(int id) async {
    emit(const ProyectoLoading());
    try {
      await _eliminar(id);
      emit(const ProyectoEliminado());
    } on ProyectoNoEncontradoException {
      emit(const ProyectoError('El proyecto no existe.'));
    } on ProyectoConReportesException {
      emit(const ProyectoError(
        'No es posible eliminar un proyecto con reportes exportados.',
      ));
    } catch (_) {
      emit(const ProyectoError('No se pudo eliminar el proyecto.'));
    }
  }
}
