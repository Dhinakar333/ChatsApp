import 'package:chatsapp/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    _nameFocus.dispose();
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
                                  const SizedBox(height: 70),
                                  const Text("Welcome to"),
                                  Image.asset("assets/chatsapplogo.png",height: 150,width: 150,),
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
                  controller: nameCtrl,
                  focusNode: _nameFocus,
                  decoration: InputDecoration(
                      labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Enter name';
                    if (value.length < 2) return 'Name must be at least 2 characters';
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (_isDesktop) FocusScope.of(context).requestFocus(_emailFocus);
                  },
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: emailCtrl,
                  focusNode: _emailFocus,
                  decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelText: 'Email'),
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
                      labelText: 'Password'),
                  obscureText: true,
                  validator: (v) {
                    final value = v ?? '';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!_isDesktop) return;
                    if (!_formKey.currentState!.validate()) return;
                    context.read<AuthBloc>().add(
                      AuthSignupRequested(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        password: passCtrl.text.trim(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    context.read<AuthBloc>().add(
                      AuthSignupRequested(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        password: passCtrl.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Sign Up'),
                ),
                TextButton(onPressed: (){
                  final nav = Navigator.of(context);
                  if (nav.canPop()) {
                    nav.pop();
                    return;
                  }
                  nav.pushReplacement(MaterialPageRoute(builder: (context) => LoginScreen()));
                }, child: Text("Already have account?"))
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
