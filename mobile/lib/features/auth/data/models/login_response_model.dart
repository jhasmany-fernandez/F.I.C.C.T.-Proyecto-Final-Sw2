import 'usuario_model.dart';

/// Modelo de la respuesta JSON del endpoint POST /auth/login.
/// El backend retorna access_token, refresh_token y el perfil del usuario.
/// PB-09 — Sprint 1 (Sp1-13)
class LoginResponseModel {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final UsuarioModel usuario;

  const LoginResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.usuario,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      usuario: UsuarioModel.fromJson(
        json['usuario'] as Map<String, dynamic>,
      ),
    );
  }
}
