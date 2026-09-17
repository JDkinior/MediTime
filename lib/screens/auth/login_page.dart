import 'package:flutter/material.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:meditime/services/auth_service.dart'; // Importa tu servicio
import 'package:meditime/theme/app_theme.dart';
import 'package:provider/provider.dart'; // Importa Provider
import 'register_page.dart';
import 'package:meditime/widgets/primary_button.dart';
import 'package:meditime/widgets/styled_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.openLoginPanel = false});

  final bool openLoginPanel;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _showLoginForm = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _emailError = false;
  bool _passwordError = false;
  String _emailErrorText = '';
  String _passwordErrorText = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    if (widget.openLoginPanel) {
      _showLoginForm = true;
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleLoginForm() {
    final shouldShow = !_showLoginForm;
    setState(() {
      _showLoginForm = shouldShow;
    });
    if (shouldShow) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    bool emailError = false;
    String emailErrorText = '';
    bool passwordError = false;
    String passwordErrorText = '';

    if (email.isEmpty) {
      emailError = true;
      emailErrorText = l10n?.loginErrorEmptyEmail ?? 'Por favor ingresa tu correo';
    }
    if (password.isEmpty) {
      passwordError = true;
      passwordErrorText = l10n?.loginErrorEmptyPassword ?? 'Por favor ingresa tu contraseña';
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
    final result = await authService.signInWithEmailAndPassword(email, password);

    if (!mounted) return;

    if (result.isFailure) {
      final error = result.error ?? (l10n?.loginErrorGeneral ?? 'Error al iniciar sesión');
      bool newEmailError = false;
      String newEmailErrorText = '';
      bool newPasswordError = false;
      String newPasswordErrorText = '';
      String errorMessage = '';

      final normalizedError = error.toLowerCase();
      if (normalizedError.contains('user-not-found')) {
        newEmailError = true;
        newEmailErrorText = l10n?.loginErrorUserNotFound ?? 'Usuario no encontrado';
      } else if (normalizedError.contains('wrong-password')) {
        newPasswordError = true;
        newPasswordErrorText = l10n?.loginErrorWrongPassword ?? 'Contraseña incorrecta';
      } else if (normalizedError.contains('invalid-email')) {
        newEmailError = true;
        newEmailErrorText = l10n?.loginErrorInvalidEmail ?? 'Formato de correo inválido';
      } else {
        errorMessage = error;
      }

      setState(() {
        _isLoading = false;
        _emailError = newEmailError;
        _emailErrorText = newEmailErrorText;
        _passwordError = newPasswordError;
        _passwordErrorText = newPasswordErrorText;
        _errorMessage = errorMessage;
      });
      return;
    }

    setState(() => _isLoading = false);

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
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

    if (result.isFailure) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isLoading = false;
        _errorMessage = result.error ?? (l10n?.loginErrorGoogle ?? 'Error al iniciar sesión con Google. Inténtalo de nuevo.');
      });
      return;
    }

    setState(() => _isLoading = false);

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    final bottomInset = mediaQuery.viewInsets.bottom;

    return PopScope(
      canPop: !_showLoginForm,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showLoginForm) {
          _toggleLoginForm();
        }
      },
      child: GestureDetector(
        onTap: () {
          final currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
          }
          if (_showLoginForm) {
            _toggleLoginForm();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppTheme.backgroundColor,
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  height: screenHeight - (screenHeight * 0.4 * _animationController.value),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 73, 194, 255),
                        Color.fromARGB(255, 47, 109, 180),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              child: SizedBox(
                width: screenWidth,
                height: screenHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // --- OPTIMIZACIÓN 1: Título de la App ---
                    AnimatedBuilder(
                      animation: _animationController,
                      // El contenido del título se construye una sola vez.
                      child: Column(
                        children: [
                          const Text(
                            'MediTime',
                            style: TextStyle(
                              fontSize: 55,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            l10n?.loginSlogan ?? 'Controla tus medicamentos\nMejora tu salud',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      builder: (context, child) {
                        // El builder solo reconstruye el Positioned, que es ligero.
                        return Positioned(
                          top: screenHeight * 0.35 - (screenHeight * 0.24 * _animationController.value),
                          child: child!, // Usamos el child pre-construido.
                        );
                      },
                    ),

                    // --- OPTIMIZACIÓN 2: Botones de Autenticación Iniciales ---
                    AnimatedBuilder(
                      animation: _animationController,
                      // El contenido (los botones) se construye una sola vez.
                      child: Column(
                        children: [
                          _SingButton(
                            text: l10n?.loginSignIn ?? 'Iniciar sesión',
                            onPressed: _toggleLoginForm,
                          ),
                          const SizedBox(height: 20),
                          _AuthButton(
                            text: l10n?.loginRegister ?? 'Registrarme',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterPage()),
                            ),
                          ),
                        ],
                      ),
                      builder: (context, child) {
                        final opacity = (1.0 - _animationController.value * 2).clamp(0.0, 1.0);
                        // El builder solo reconstruye Positioned, Opacity y Visibility.
                        return Positioned(
                          top: screenHeight * 0.75,
                          child: Opacity(
                            opacity: opacity,
                            child: Visibility(
                              visible: _animationController.value < 0.5,
                              child: child!, // Usamos el child pre-construido.
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // --- OPTIMIZACIÓN 3: Formulario de Login Deslizable (LA MÁS IMPORTANTE) ---
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _animationController,
                // El formulario completo se construye una sola vez y se pasa como 'child'.
                child: GestureDetector(
                  onTap: () {
                    final currentFocus = FocusScope.of(context);
                    if (!currentFocus.hasPrimaryFocus) {
                      currentFocus.unfocus();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: screenHeight * 0.63,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                offset: const Offset(0, -4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, -4),
                              ),
                            ],
                    ),
                    padding: const EdgeInsets.all(30),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: bottomInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           const SizedBox(height: 5),
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
                          const SizedBox(height: 15),
                          StyledTextField(
                            controller: _passwordController,
                            labelText: l10n?.loginPasswordLabel ?? 'Contraseña',
                            hintText: l10n?.loginPasswordHint ?? 'Escribe tu contraseña',
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
                          const SizedBox(height: 70),
                          PrimaryButton(
                            text: l10n?.loginButton ?? 'Iniciar Sesión',
                            isLoading: _isLoading,
                            onPressed: _login,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: Divider(color: AppTheme.borderColor, thickness: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(l10n?.loginOr ?? 'o', style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 14)),
                              ),
                              Expanded(child: Divider(color: AppTheme.borderColor, thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton.icon(
                              icon: Image.asset('assets/google_logo.png', width: 30, height: 30),
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
                                  side: BorderSide(color: AppTheme.borderColor),
                                ),
                                elevation: 0,
                              ),
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterPage()),
                              ),
                              child: Text(
                                l10n?.loginNoAccount ?? '¿No tienes cuenta? Regístrate aquí',
                                style: TextStyle(color: AppTheme.primaryColor, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, screenHeight * 0.63 * (1 - _animationController.value)),
                    child: child!, // Usamos el 'child' que ya fue construido.
                  );
                },
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _AuthButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 350,
      height: 65,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(0, 255, 255, 255),
          foregroundColor: const Color(0xFF2F71B6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide( // Aquí añadimos el borde
              color: Colors.white, // Color del borde
              width: 2.0, // Grosor del borde
            ),
          ),
          elevation: 0, // Sin sombra
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SingButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _SingButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 350,
      height: 65,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF2F71B6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0, // Sin sombra
        ),
        onPressed: onPressed,
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              colors: [
                Color.fromARGB(255, 73, 194, 255),
                Color.fromARGB(255, 47, 109, 180),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds);
          },
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.white, // El color del texto debe ser blanco para que el degradado sea visible
            ),
          ),
        ),
      ),
    );
  }
}