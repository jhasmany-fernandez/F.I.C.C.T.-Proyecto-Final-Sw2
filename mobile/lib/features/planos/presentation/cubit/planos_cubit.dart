import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/plano.dart';
import '../../domain/repositories/plano_repository.dart';
import '../../domain/usecases/plano_usecases.dart';
import 'planos_state.dart';

/// Cubit del feature Planos. Mantiene la lista reactiva por proyecto.
/// HU PB-02 / PB-11 — Sprint 2.
class PlanosCubit extends Cubit<PlanosState> {
  final ListarPlanosUseCase _listar;
  final ImportarPlanoUseCase _importar;
  final CalibrarPlanoUseCase _calibrar;
  final EliminarPlanoUseCase _eliminar;

  /// Proyecto actualmente seleccionado.
  int? _proyectoId;

  PlanosCubit({
    required ListarPlanosUseCase listar,
    required ImportarPlanoUseCase importar,
    required CalibrarPlanoUseCase calibrar,
    required EliminarPlanoUseCase eliminar,
  })  : _listar = listar,
        _importar = importar,
        _calibrar = calibrar,
        _eliminar = eliminar,
        super(const PlanosInitial());

  /// Lista actual (vacía si no se cargó aún).
  List<Plano> get _listaActual => switch (state) {
        PlanosListaExitosa(:final planos) => planos,
        PlanosOperacionExitosa(:final planos) => planos,
        PlanosError(:final planos) => planos,
        _ => const <Plano>[],
      };

  /// Carga inicial / refresh.
  Future<void> cargarPlanos(int proyectoId) async {
    _proyectoId = proyectoId;
    emit(const PlanosLoading());
    try {
      final planos = await _listar(proyectoId);
      emit(PlanosListaExitosa(planos));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return;
      emit(const PlanosError('No se pudo cargar los planos del proyecto.'));
    } catch (_) {
      emit(const PlanosError('No se pudo cargar los planos del proyecto.'));
    }
  }

  /// Importa un plano. PB-02.
  Future<void> importarPlano({
    required String rutaArchivo,
    String? nombre,
  }) async {
    final proyectoId = _proyectoId;
    if (proyectoId == null) {
      emit(const PlanosError('No hay proyecto seleccionado.'));
      return;
    }

    final actuales = _listaActual;
    emit(const PlanosLoading());
    try {
      final plano = await _importar(
        proyectoId: proyectoId,
        rutaArchivo: rutaArchivo,
        nombre: nombre,
      );
      final mensaje = plano.warning != null
          ? 'Plano "${plano.nombre}" importado. ${plano.warning}'
          : 'Plano "${plano.nombre}" importado.';
      final lista = await _listar(proyectoId);
      emit(PlanosOperacionExitosa(
        planos: lista,
        mensaje: mensaje,
        planoAfectado: plano,
      ));
    } on PlanoArchivoMuyGrandeException {
      emit(PlanosError(
        'El archivo excede 20 MB.',
        planos: actuales,
      ));
    } on PlanoFormatoNoSoportadoException catch (e) {
      emit(PlanosError(
        e.toString(),
        planos: actuales,
      ));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return;
      emit(PlanosError(
        'No se pudo importar el plano.',
        planos: actuales,
      ));
    } catch (_) {
      emit(PlanosError(
        'No se pudo importar el plano.',
        planos: actuales,
      ));
    }
  }

  /// Calibra la escala de un plano. PB-11.
  Future<void> calibrarPlano({
    required int planoId,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required double distanciaRealM,
  }) async {
    final actuales = _listaActual;
    emit(const PlanosLoading());
    try {
      final plano = await _calibrar(
        planoId: planoId,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        distanciaRealM: distanciaRealM,
      );
      final lista = _proyectoId != null
          ? await _listar(_proyectoId!)
          : actuales;
      emit(PlanosOperacionExitosa(
        planos: lista,
        mensaje: 'Escala calibrada: '
            '${plano.escalaMPorPx!.toStringAsFixed(4)} m/px.',
        planoAfectado: plano,
      ));
    } on PlanoDistanciaInvalidaException catch (e) {
      emit(PlanosError(e.toString(), planos: actuales));
    } on PlanoPuntosInvalidosException catch (e) {
      emit(PlanosError(e.toString(), planos: actuales));
    } on PlanoRecalibracionBloqueadaException catch (e) {
      emit(PlanosError(e.toString(), planos: actuales));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return;
      emit(PlanosError('No se pudo calibrar el plano.', planos: actuales));
    } catch (_) {
      emit(PlanosError('No se pudo calibrar el plano.', planos: actuales));
    }
  }

  /// Elimina un plano.
  Future<void> eliminarPlano(int planoId) async {
    final actuales = _listaActual;
    emit(const PlanosLoading());
    try {
      await _eliminar(planoId);
      final lista = _proyectoId != null
          ? await _listar(_proyectoId!)
          : actuales.where((p) => p.id != planoId).toList();
      emit(PlanosOperacionExitosa(
        planos: lista,
        mensaje: 'Plano eliminado.',
      ));
    } on PlanoNoEncontradoException {
      emit(PlanosError('El plano no existe.', planos: actuales));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return;
      emit(PlanosError('No se pudo eliminar el plano.', planos: actuales));
    } catch (_) {
      emit(PlanosError('No se pudo eliminar el plano.', planos: actuales));
    }
  }
}
