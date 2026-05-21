import 'package:equatable/equatable.dart';

import '../../domain/entities/plano.dart';

/// Estados del cubit de planos.
sealed class PlanosState extends Equatable {
  const PlanosState();

  @override
  List<Object?> get props => [];
}

class PlanosInitial extends PlanosState {
  const PlanosInitial();
}

class PlanosLoading extends PlanosState {
  const PlanosLoading();
}

/// Lista de planos cargada exitosamente.
class PlanosListaExitosa extends PlanosState {
  final List<Plano> planos;
  const PlanosListaExitosa(this.planos);

  @override
  List<Object?> get props => [planos];
}

/// Operación (importar / calibrar / eliminar) exitosa.
class PlanosOperacionExitosa extends PlanosState {
  final List<Plano> planos;
  final String mensaje;
  final Plano? planoAfectado;
  const PlanosOperacionExitosa({
    required this.planos,
    required this.mensaje,
    this.planoAfectado,
  });

  @override
  List<Object?> get props => [planos, mensaje, planoAfectado];
}

/// Error de la operación. La lista (si existe) se preserva.
class PlanosError extends PlanosState {
  final String mensaje;
  final List<Plano> planos;
  const PlanosError(this.mensaje, {this.planos = const []});

  @override
  List<Object?> get props => [mensaje, planos];
}
