import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_branding_header.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/auth_state.dart';
import '../widgets/login_form.dart';

/// Pantalla de inicio de sesión.
/// Sp-05 — PB-09
/// CA-1: navega a /proyectos en menos de 2 s al autenticar correctamente.
/// CA-2: muestra mensaje de error genérico sin revelar qué campo falló.
/// CA-4: cerrar sesión redirige aquí y elimina sesión local.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/proyectos');
          }
          if (state is AuthError) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.mensaje),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xxl,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  AppBrandingHeader(logoSize: 96),
                  SizedBox(height: AppSpacing.xxxl),
                  LoginForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
