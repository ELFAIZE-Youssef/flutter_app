import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _loading = false;

  final _formKey = GlobalKey<FormState>();

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      Navigator.pushReplacementNamed(context, "/home");

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Login failed")),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.jpg', height: 100),
              const SizedBox(height: 30),

              TextFormField(
                controller: _emailController,
                decoration: _input("Email", Icons.email),
                validator: (value) =>
                    value!.contains("@") ? null : "Invalid email",
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: _passwordField("Password"),
                validator: (value) =>
                    value!.length >= 6 ? null : "Min 6 characters",
              ),
              const SizedBox(height: 20),

              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.teal,
                      ),
                      child: const Text("Login", style: TextStyle(fontSize: 18)),
                    ),

              TextButton(
                onPressed: () => Navigator.pushNamed(context, "/register"),
                child: const Text("Don't have an account? Register here"),
              )
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String text, IconData icon) {
    return InputDecoration(
      labelText: text,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  InputDecoration _passwordField(String text) {
    return InputDecoration(
      labelText: text,
      prefixIcon: const Icon(Icons.lock),
      suffixIcon: IconButton(
        icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
        onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
