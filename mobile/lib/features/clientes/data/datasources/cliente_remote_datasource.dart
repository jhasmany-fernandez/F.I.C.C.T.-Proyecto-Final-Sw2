import 'package:dio/dio.dart';

/// Modelo liviano para el selector de clientes en el formulario de proyecto.
class ClienteItem {
  final int id;
  final String nombre;

  const ClienteItem({required this.id, required this.nombre});

  factory ClienteItem.fromJson(Map<String, dynamic> json) => ClienteItem(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
      );
}

/// Datasource remoto para listar clientes activos.
/// Usado por el formulario de proyecto para poblar el selector.
/// PB-19 — Sp1-35
class ClienteRemoteDatasource {
  final Dio _dio;

  const ClienteRemoteDatasource(this._dio);

  Future<List<ClienteItem>> listarActivos() async {
    final response = await _dio.get<List<dynamic>>('/clientes');
    return (response.data ?? [])
        .map((e) => ClienteItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
