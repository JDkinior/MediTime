import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Mantener para FirebaseAuthException
import 'package:meditime/services/auth_service.dart'; // Importa tu servicio
import 'package:provider/provider.dart'; // Importa Provider
import 'register_page.dart';
import 'package:meditime/widgets/primary_button.dart';
import 'package:meditime/widgets/styled_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _showLoginForm = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  final FocusNode _passwordFocusNode = FocusNode();
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _toggleLoginForm() {
    setState(() {
      _showLoginForm = !_showLoginForm;
      if (_showLoginForm) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _login() async {
    // Limpieza de errores (sin cambios)
    setState(() {
      _emailError = false;
      _passwordError = false;
      _emailErrorText = '';
      _passwordErrorText = '';
      _errorMessage = '';
    });

    // Validaciones (sin cambios)
    bool hasErrors = false;
    if (_emailController.text.isEmpty) {
      setState(() {
        _emailError = true;
        _emailErrorText = 'Por favor ingresa tu correo';
        hasErrors = true;
      });
    }
    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = true;
        _passwordErrorText = 'Por favor ingresa tu contraseña';
        hasErrors = true;
      });
    }
    if (hasErrors) return;

    setState(() => _isLoading = true);

    try {
      // *** CAMBIO CLAVE: Usa el AuthService a través de Provider ***
      final authService = context.read<AuthService>();
      await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // El AuthWrapper se encargará de navegar a HomePage, por lo que no necesitamos hacer nada aquí.
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          setState(() {
            _emailError = true;
            _emailErrorText = 'Usuario no encontrado';
          });
          break;
        case 'wrong-password':
          setState(() {
            _passwordError = true;
            _passwordErrorText = 'Contraseña incorrecta';
          });
          break;
        case 'invalid-email':
          setState(() {
            _emailError = true;
            _emailErrorText = 'Formato de correo inválido';
          });
          break;
        default:
          setState(() => _errorMessage = 'Error: ${e.message}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

    Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = context.read<AuthService>();
      await authService.signInWithGoogle();
      // El AuthWrapper se encargará de la navegación
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al iniciar sesión con Google. Inténtalo de nuevo.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
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
                      child: const Column(
                        children: [
                          Text(
                            'MediTime',
                            style: TextStyle(
                              fontSize: 55,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Controla tus medicamentos\nMejora tu salud',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
                            text: 'Iniciar sesión',
                            onPressed: _toggleLoginForm,
                          ),
                          const SizedBox(height: 20),
                          _AuthButton(
                            text: 'Registrarme',
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
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    padding: const EdgeInsets.all(30),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           const SizedBox(height: 5),
                          StyledTextField(
                            controller: _emailController,
                            labelText: 'Correo Electrónico',
                            hintText: 'Escribe tu correo electrónico',
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
                            labelText: 'Contraseña',
                            hintText: 'Escribe tu contraseña',
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
                            text: 'Iniciar Sesión',
                            isLoading: _isLoading,
                            onPressed: _login,
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              Expanded(child: Divider(color: Color.fromARGB(255, 165, 165, 165), thickness: 1)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('o', style: TextStyle(color: Color.fromARGB(255, 165, 165, 165), fontSize: 14)),
                              ),
                              Expanded(child: Divider(color: Color.fromARGB(255, 165, 165, 165), thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton.icon(
                              icon: Image.asset('assets/google_logo.png', width: 30, height: 30),
                              label: const Text('Continuar con Google'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF3F3F3),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: const BorderSide(color: Color.fromARGB(255, 165, 165, 165)),
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
                              child: const Text(
                                '¿No tienes cuenta? Regístrate aquí',
                                style: TextStyle(color: Color.fromARGB(255, 47, 109, 180), fontSize: 15, fontWeight: FontWeight.w600),
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