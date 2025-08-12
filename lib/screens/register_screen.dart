import 'package:chatsapp/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: auth.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 70,),
                Text("Welcome to"),
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
                  decoration: InputDecoration(
                      labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),),
                  validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelText: 'Email'),
                  validator: (v) => v == null || v.isEmpty ? 'Enter email' : null,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: passCtrl,
                  decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => v == null || v.length < 6 ? '6+ chars' : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    await auth.signup(nameCtrl.text.trim(), emailCtrl.text.trim(), passCtrl.text.trim());
                    if (auth.error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error!)));
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Sign Up'),
                ),
                TextButton(onPressed: (){
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (context)=>LoginScreen()));
                }, child: Text("Already have account?"))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
