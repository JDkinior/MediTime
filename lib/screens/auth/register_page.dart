import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    // Limpia errores
    setState(() {
      _emailError = false;
      _passwordError = false;
      _emailErrorText = '';
      _passwordErrorText = '';
      _errorMessage = '';
    });

    // Validaciones
    bool hasErrors = false;
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      setState(() {
        _emailError = true;
        _emailErrorText = 'Por favor ingresa un correo válido';
        hasErrors = true;
      });
    }
    if (_passwordController.text.isEmpty || _passwordController.text.length < 6) {
      setState(() {
        _passwordError = true;
        _passwordErrorText = 'La contraseña debe tener al menos 6 caracteres';
        hasErrors = true;
      });
    }
    if (hasErrors) return;

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.createUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'El correo ya está en uso';
          break;
        case 'weak-password':
          message = 'La contraseña es demasiado débil';
          break;
        default:
          message = 'Error: ${e.message}';
      }
      setState(() => _errorMessage = message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
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
