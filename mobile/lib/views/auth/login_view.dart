import 'package:flutter/material.dart';

/// Login/cadastro via Supabase Auth.
class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar')),
      body: const Center(child: Text('TODO: integração com supabase_flutter')),
    );
  }
}
