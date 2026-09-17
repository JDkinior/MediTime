import 'package:flutter/material.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:provider/provider.dart';

// CAMBIO: Importar los nuevos widgets reutilizables
import 'package:meditime/widgets/primary_button.dart';
import 'package:meditime/widgets/styled_text_field.dart';

// CAMBIO: La navegación ahora apunta a la nueva ubicación de LoginPage
import 'package:meditime/screens/auth/login_page.dart';


class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _emailError = false;
  bool _passwordError = false;
  String _emailErrorText = '';
  String _passwordErrorText = '';

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    bool emailError = false;
    String emailErrorText = '';
    bool passwordError = false;
    String passwordErrorText = '';

    if (email.isEmpty || !email.contains('@')) {
      emailError = true;
      emailErrorText = l10n?.registerErrorInvalidEmail ?? 'Por favor ingresa un correo válido';
    }
    if (password.isEmpty || password.length < 6) {
      passwordError = true;
      passwordErrorText = l10n?.registerErrorShortPassword ?? 'La contraseña debe tener al menos 6 caracteres';
    }

    if (emailError || passwordError) {
      setState(() {
        _emailError = emailError;
        _emailErrorText = emailErrorText;
        _passwordError = passwordError;
        _passwordErrorText = passwordErrorText;
        _errorMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = false;
      _passwordError = false;
      _emailErrorText = '';
      _passwordErrorText = '';
      _errorMessage = '';
    });

    final authService = context.read<AuthService>();
    final result = await authService.createUserWithEmailAndPassword(
      email,
      password,
    );

    if (!mounted) return;

    if (result.isFailure) {
      final error = result.error ?? (l10n?.registerErrorFailed ?? 'No se pudo crear la cuenta');
      final normalized = error.toLowerCase();
      String message;

      if (normalized.contains('email-already-in-use')) {
        message = l10n?.registerErrorEmailInUse ?? 'El correo ya está en uso';
      } else if (normalized.contains('weak-password')) {
        message = l10n?.registerErrorWeakPassword ?? 'La contraseña es demasiado débil';
      } else if (normalized.contains('invalid-email')) {
        message = l10n?.loginErrorInvalidEmail ?? 'Formato de correo inválido';
      } else {
        message = error;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      return;
    }

    setState(() => _isLoading = false);

    if (Navigator.canPop(context)) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
  
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final authService = context.read<AuthService>();
    final result = await authService.signInWithGoogle();

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.isSuccess) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = result.error ??
            (l10n?.registerErrorGoogle ?? 'Error al registrarse con Google. Inténtalo de nuevo.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 40),
                Text(
                  l10n?.registerTitle ?? 'Crear cuenta',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n?.registerSubtitle ?? 'Comienza a gestionar tus medicamentos',
                  style: TextStyle(fontSize: 16, color: AppTheme.secondaryTextColor),
                ),
                const SizedBox(height: 40),
                
                // CAMBIO: Usamos nuestro widget reutilizable
                StyledTextField(
                  controller: _emailController,
                  labelText: l10n?.loginEmailLabel ?? 'Correo Electrónico',
                  hintText: l10n?.loginEmailHint ?? 'Escribe tu correo electrónico',
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError ? _emailErrorText : null,
                  onChanged: (_) {
                    if (_emailError) {
                      setState(() {
                        _emailError = false;
                        _emailErrorText = '';
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),
                
                // CAMBIO: Usamos nuestro widget reutilizable
                StyledTextField(
                  controller: _passwordController,
                  labelText: l10n?.loginPasswordLabel ?? 'Contraseña',
                  hintText: l10n?.registerPasswordHint ?? 'Crea tu contraseña',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  errorText: _passwordError ? _passwordErrorText : null,
                  onChanged: (_) {
                    if (_passwordError) {
                      setState(() {
                        _passwordError = false;
                        _passwordErrorText = '';
                      });
                    }
                  },
                ),
                const SizedBox(height: 40),

                // CAMBIO: Usamos nuestro botón reutilizable
                PrimaryButton(
                  text: l10n?.registerButton ?? 'Registrarme',
                  isLoading: _isLoading,
                  onPressed: _register,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppTheme.borderColor,
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        l10n?.loginOr ?? 'o',
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppTheme.borderColor,
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    icon: Image.asset(
                      'assets/google_logo.png',
                      width: 30,
                      height: 30,
                    ),
                    label: Text(
                      l10n?.loginWithGoogle ?? 'Continuar con Google',
                      style: TextStyle(
                        color: AppTheme.primaryTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).cardColor,
                      foregroundColor: AppTheme.primaryTextColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: AppTheme.borderColor,
                        ),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _signInWithGoogle,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(openLoginPanel: true),
                      ),
                    ),
                    child: Text(
                      l10n?.registerAlreadyHaveAccount ?? '¿Ya tienes cuenta? Inicia sesión aquí',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
