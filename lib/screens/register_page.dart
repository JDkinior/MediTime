import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _emailError = false;
  bool _passwordError = false;
  String _emailErrorText = '';
  String _passwordErrorText = '';

  Future<void> _register() async {
    setState(() {
      _emailError = false;
      _passwordError = false;
      _emailErrorText = '';
      _passwordErrorText = '';
      _errorMessage = '';
    });

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
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pop(context);
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
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_passwordError) {
              setState(() {
                _passwordError = false;
                _passwordErrorText = '';
              });
            }
          },
          decoration: InputDecoration(
            hintText: 'Crea tu contraseña',
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54),
                ),
                const SizedBox(height: 40),
                _buildEmailField(),
                const SizedBox(height: 20),
                _buildPasswordField(),
                const SizedBox(height: 40),
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
                    onPressed: _isLoading ? null : _register,
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
                                'Registrarme',
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                  ),
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