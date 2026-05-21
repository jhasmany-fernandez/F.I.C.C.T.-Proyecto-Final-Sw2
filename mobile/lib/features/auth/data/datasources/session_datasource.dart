import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/usuario.dart';
import '../models/usuario_model.dart';

/// Gestión de sesión persistente mediante [FlutterSecureStorage].
/// Almacena el access token, el refresh token y el perfil del usuario activo.
/// Modalidad 100 % en línea: no hay sqflite — el perfil se cacheía
/// localmente en secure storage para evitar un request extra al abrir la app.
/// PB-09 — Sprint 1 (Sp1-16)
class SessionDatasource {
  static const String _keyToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUsuarioJson = 'usuario_json';

  final FlutterSecureStorage _storage;

  SessionDatasource(this._storage);

  /// Persiste el [accessToken], el [refreshToken] y el perfil del [usuario].
  Future<void> guardarSesion(
    String accessToken,
    String refreshToken,
    Usuario usuario,
  ) async {
    final json = jsonEncode(UsuarioModel.fromDomain(usuario).toJson());
    await Future.wait([
      _storage.write(key: _keyToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
      _storage.write(key: _keyUsuarioJson, value: json),
    ]);
  }

  /// Retorna el access token JWT si existe sesión activa, o `null` si no.
  Future<String?> obtenerToken() async {
    return _storage.read(key: _keyToken);
  }

  /// Retorna el refresh token si existe, o `null` si no hay sesión.
  Future<String?> obtenerRefreshToken() async {
    return _storage.read(key: _keyRefreshToken);
  }

  /// Retorna el [Usuario] con sesión activa, o `null` si no hay sesión.
  Future<Usuario?> obtenerUsuario() async {
    final raw = await _storage.read(key: _keyUsuarioJson);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return UsuarioModel.fromJson(map).toDomain();
  }

  /// Elimina la sesión del almacenamiento seguro.
  Future<void> limpiarSesion() async {
    await Future.wait([
      _storage.delete(key: _keyToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyUsuarioJson),
    ]);
  }
}
