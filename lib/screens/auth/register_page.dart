import 'package:flutter/material.dart';
import 'package:meditime/services/auth_service.dart';
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
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();

    bool emailError = false;
    String emailErrorText = '';
    bool passwordError = false;
    String passwordErrorText = '';

    if (email.isEmpty || !email.contains('@')) {
      emailError = true;
      emailErrorText = 'Por favor ingresa un correo válido';
    }
    if (password.isEmpty || password.length < 6) {
      passwordError = true;
      passwordErrorText = 'La contraseña debe tener al menos 6 caracteres';
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
      final error = result.error ?? 'No se pudo crear la cuenta';
      final normalized = error.toLowerCase();
      String message;

      if (normalized.contains('email-already-in-use')) {
        message = 'El correo ya está en uso';
      } else if (normalized.contains('weak-password')) {
        message = 'La contraseña es demasiado débil';
      } else if (normalized.contains('invalid-email')) {
        message = 'Formato de correo inválido';
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
      setState(() {
        _errorMessage = result.error ??
            'Error al registrarse con Google. Inténtalo de nuevo.';
      });
    }
  }
  
  // ELIMINAMOS los métodos _buildEmailField() y _buildPasswordField() de aquí

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F3F3),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF2F71B6)),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Crear cuenta',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2F71B6),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Comienza a gestionar tus medicamentos',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 40),
                
                // CAMBIO: Usamos nuestro widget reutilizable
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
                const SizedBox(height: 20),
                
                // CAMBIO: Usamos nuestro widget reutilizable
                StyledTextField(
                  controller: _passwordController,
                  labelText: 'Contraseña',
                  hintText: 'Crea tu contraseña',
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
                  text: 'Registrarme',
                  isLoading: _isLoading,
                  onPressed: _register,
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
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
                    label: const Text('Continuar con Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F3F3),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(
                          color: Color.fromARGB(255, 165, 165, 165),
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
                    child: const Text(
                      '¿Ya tienes cuenta? Inicia sesión aquí',
                      style: TextStyle(
                          color: Color(0xFF2F71B6),
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
