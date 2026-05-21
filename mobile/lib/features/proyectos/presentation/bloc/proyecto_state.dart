import 'package:equatable/equatable.dart';
import '../../domain/entities/proyecto.dart';

/// Estados del flujo de gestión de proyectos.
/// HU PB-01 — Sp-12
sealed class ProyectoState extends Equatable {
  const ProyectoState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial; aún no se ha cargado la lista.
final class ProyectoInitial extends ProyectoState {
  const ProyectoInitial();
}

/// Cargando la lista o procesando una operación (crear/editar/archivar/eliminar).
final class ProyectoLoading extends ProyectoState {
  const ProyectoLoading();
}

/// Lista de proyectos activos cargada correctamente.
final class ProyectoListaExitosa extends ProyectoState {
  final List<Proyecto> proyectos;

  const ProyectoListaExitosa(this.proyectos);

  @override
  List<Object?> get props => [proyectos];
}

/// Operación de creación/edición completada. La UI debe recargar la lista.
final class ProyectoOperacionExitosa extends ProyectoState {
  final Proyecto proyecto;
  final String mensaje;

  const ProyectoOperacionExitosa(
      {required this.proyecto, required this.mensaje});

  @override
  List<Object?> get props => [proyecto, mensaje];
}

/// El proyecto fue eliminado correctamente. La UI debe recargar la lista.
final class ProyectoEliminado extends ProyectoState {
  const ProyectoEliminado();
}

/// Error en alguna operación de proyecto.
final class ProyectoError extends ProyectoState {
  final String mensaje;

  const ProyectoError(this.mensaje);

  @override
  List<Object?> get props => [mensaje];
}
