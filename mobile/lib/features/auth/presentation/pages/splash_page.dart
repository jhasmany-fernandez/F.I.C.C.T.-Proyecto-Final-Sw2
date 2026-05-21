import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_branding_header.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/auth_state.dart';

/// Pantalla inicial: muestra branding mientras se valida la sesión activa.
/// El [BlocListener] redirige a `/login` o `/proyectos` según el estado.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Disparar verificación de sesión tras el primer frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthCubit>().checkSesionActiva();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/proyectos');
          } else if (state is AuthUnauthenticated || state is AuthSinConexion) {
            context.go('/login');
          }
        },
        child: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppBrandingHeader(logoSize: 120),
                  SizedBox(height: 40),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
