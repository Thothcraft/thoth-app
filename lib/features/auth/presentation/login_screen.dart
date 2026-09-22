import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await ref
        .read(authProvider.notifier)
        .login(_username.text, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.go('/devices');
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(authProvider).error;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/images/thoth_logo.png',
                        height: 72,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.science, size: 72),),
                    const SizedBox(height: 16),
                    Text('Sign in to ThothCraft',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(
                          labelText: 'Username or email',
                          prefixIcon: Icon(Icons.person),),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(error,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error,),
                          textAlign: TextAlign.center,),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),)
                          : const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
