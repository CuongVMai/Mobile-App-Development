import 'package:flutter/material.dart';

import 'auth_service.dart';

////// one screen that does both Sign in and Register //////
class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isRegister =
      false; ////// false = sign in mode, true = register mode //////
  bool _loading = false;
  String? _error;

  ////// dispose controllers so they don't leak //////
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    ////// block double taps while a request is already running //////
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isRegister) {
        await AuthService.instance.register(_email.text, _password.text);
      } else {
        await AuthService.instance.signIn(_email.text, _password.text);
      }
      ////// no Navigator here: AuthGate sees the new user and shows ProfileScreen //////
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AuthService.friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegister = !_isRegister;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegister ? 'Create account' : 'Sign in';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email'),
                  ////// email format check //////
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Email is required';
                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(email);
                    if (!ok) return 'Enter a valid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  enabled: !_loading,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  ////// 6-character baseline (Firebase's policy is still the final check) //////
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Password is required';
                    if (value.length < 6)
                      return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ////// friendly error message from AuthService //////
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ElevatedButton(
                  ////// disabled while loading = no duplicate submissions //////
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isRegister ? 'Register' : 'Sign in'),
                ),
                TextButton(
                  onPressed: _loading ? null : _toggleMode,
                  child: Text(
                    _isRegister
                        ? 'Already have an account? Sign in'
                        : 'No account? Register',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
