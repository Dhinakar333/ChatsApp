import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool get _isDesktop {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (prev, next) =>
          prev.errorMessage != next.errorMessage && next.errorMessage != null || prev.status != next.status,
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }
        final msg = state.errorMessage;
        if (msg == null) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      builder: (context, state) {
        final isLoading = state.status == AuthStatus.loading;
        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth >= 700 ? 460.0 : double.infinity;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Form(
                            key: _formKey,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Welcome to"),
                                  Image.asset(
                                    "assets/chatsapplogo.png",
                                    height: 150,
                                    width: 150,
                                  ),
                    // Text(
                    //   "ChatsApp",
                    //   style: TextStyle(
                    //     fontSize: 34,
                    //     fontWeight: FontWeight.bold,
                    //     color: Colors.blue.shade700,
                    //   ),
                    // ),
                    Text(
                      "Where conversations never end.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: emailCtrl,
                      focusNode: _emailFocus,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Enter email';
                        if (!_emailRegex.hasMatch(value)) return 'Enter a valid email';
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (_isDesktop) FocusScope.of(context).requestFocus(_passFocus);
                      },
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: passCtrl,
                      focusNode: _passFocus,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelText: 'Password',
                      ),
                      obscureText: true,
                      validator: (v) =>
                          v == null || v.length < 6 ? 'Enter password with at least 6 chars' : null,
                      onFieldSubmitted: (_) {
                        if (!_isDesktop) return;
                        if (!_formKey.currentState!.validate()) return;
                        final email = emailCtrl.text.trim();
                        final pass = passCtrl.text.trim();
                        context.read<AuthBloc>().add(AuthLoginRequested(email: email, password: pass));
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          final email = emailCtrl.text.trim();
                          if (email.isEmpty || !_emailRegex.hasMatch(email)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a valid email first')),
                            );
                            return;
                          }
                          context.read<AuthBloc>().add(AuthPasswordResetRequested(email: email));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('If the email exists, reset link was sent')),
                          );
                        },
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;

                final email = emailCtrl.text.trim();
                final pass = passCtrl.text.trim();

                context.read<AuthBloc>().add(AuthLoginRequested(email: email, password: pass));
              },
              child: const Text('Login'),
            ),

            TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text('Create account'),
                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
