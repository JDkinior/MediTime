import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
  setState(() {
    _emailError = false;
    _passwordError = false;
    _emailErrorText = '';
    _passwordErrorText = '';
    _errorMessage = '';
  });

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
    await _auth.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
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

    Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Correo Electrónico',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        TextFormField(
          controller: _emailController,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_emailError) {
              setState(() {
                _emailError = false;
                _emailErrorText = '';
              });
            }
          },
          decoration: InputDecoration(
            hintText: 'Escribe tu correo electrónico',
            hintStyle: TextStyle(color: Colors.grey[400]),
            errorText: _emailError ? _emailErrorText : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: _emailError ? Colors.red : Colors.transparent,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: _emailError ? Colors.red : Colors.transparent,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: _emailError ? Colors.red : const Color(0xFF41B8DB),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Contraseña',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_passwordError) {
              setState(() {
                _passwordError = false;
                _passwordErrorText = '';
              });
            }
          },
          onFieldSubmitted: (_) => _login(),
          decoration: InputDecoration(
            hintText: 'Escribe tu contraseña',
            hintStyle: TextStyle(color: Colors.grey[400]),
            errorText: _passwordError ? _passwordErrorText : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: _passwordError ? Colors.red : Colors.transparent,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: _passwordError ? Colors.red : Colors.transparent,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: _passwordError ? Colors.red : const Color(0xFF41B8DB),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
          obscureText: true,
        ),
      ],
    );
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
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Positioned(
                          top: screenHeight * 0.35 - (screenHeight * 0.24 * _animationController.value),
                          child: Column(
                            children: [
                              Text(
                                'MediTime',
                                style: TextStyle(
                                  fontSize: 55,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Controla tus medicamentos\nMejora tu salud',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final opacity = (1.0 - _animationController.value * 2).clamp(0.0, 1.0);
                        return Positioned(
                          top: screenHeight * 0.75,
                          child: Opacity(
                            opacity: opacity,
                            child: Visibility(
                              visible: _animationController.value < 0.5,
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
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Formulario deslizable
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, screenHeight * 0.63 * (1 - _animationController.value)),
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
                          color: Color(0xFFF3F3F3),
                          borderRadius: const BorderRadius.vertical(
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
                              _buildEmailField(),
                              const SizedBox(height: 15),
                              _buildPasswordField(),
                              const SizedBox(height: 70),
                            // Botón de iniciar sesión
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _isLoading ? null : _login,
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                colors: [
                                  Color.fromARGB(255, 73, 194, 255),
                                  Color.fromARGB(255, 47, 109, 180),
                                ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: _isLoading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text(
                                            'Iniciar Sesión',
                                            style: TextStyle(fontSize: 16, color: Colors.white),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Barra separadora
                            Row(
                              children: const [
                                Expanded(
                                  child: Divider(
                                    color: Color.fromARGB(255, 165, 165, 165),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'o',
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 165, 165, 165),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Color.fromARGB(255, 165, 165, 165),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Botón de Google
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                icon: Image.asset(
                                  'assets/google_logo.png',
                                  width: 30,
                                  height: 30,
                                ),
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
                                onPressed: () {},
                              ),
                            ),
                            const SizedBox(height: 15),
                            // Enlace a registro
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterPage()),
                                ),
                                child: const Text(
                                  '¿No tienes cuenta? Regístrate aquí',
                                  style: TextStyle(
                                    color:        Color.fromARGB(255, 47, 109, 180),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (_errorMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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