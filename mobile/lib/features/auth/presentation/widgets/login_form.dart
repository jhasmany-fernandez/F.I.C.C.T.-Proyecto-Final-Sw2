import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_connection_banner.dart';
import '../../../../shared/widgets/app_loading_button.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/auth_state.dart';

/// Formulario de inicio de sesión (correo electrónico + contraseña).
/// Usa [flutter_form_builder] para validación declarativa.
/// Sp1-17 — PB-09 / Sprint 1
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _passwordVisible = false;

  void _submit() {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final datos = _formKey.currentState!.value;
    context.read<AuthCubit>().login(
          (datos['email'] as String).trim(),
          datos['password'] as String,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    final estaCargando = state is AuthLoading;
    final sinConexion = state is AuthSinConexion;
    final bloqueado = estaCargando || sinConexion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner de sin conexión (Sp1-20 / CA-5)
        if (sinConexion) ...[
          const AppConnectionBanner(),
          const SizedBox(height: AppSpacing.md),
        ],
        FormBuilder(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormBuilderTextField(
                name: 'email',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enabled: !bloqueado,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'usuario@bulldogtech.bo',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return 'Ingrese su correo electrónico';
                  }
                  if (!valor.contains('@') || !valor.contains('.')) {
                    return 'Ingrese un correo electrónico válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FormBuilderTextField(
                name: 'password',
                obscureText: !_passwordVisible,
                textInputAction: TextInputAction.done,
                enabled: !bloqueado,
                onSubmitted: (_) => bloqueado ? null : _submit(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                    tooltip: _passwordVisible ? 'Ocultar' : 'Mostrar',
                  ),
                ),
                validator: (valor) {
                  if (valor == null || valor.isEmpty) {
                    return 'Ingrese su contraseña';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              if (sinConexion) ...[
                OutlinedButton.icon(
                  onPressed: () =>
                      context.read<AuthCubit>().resetearParaReintentar(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ] else ...[
                AppLoadingButton(
                  label: 'Iniciar sesión',
                  isLoading: estaCargando,
                  onPressed: bloqueado ? null : _submit,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
