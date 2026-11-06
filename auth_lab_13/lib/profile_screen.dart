import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  bool _saving = false;
  bool _signingOut = false;

  @override
  void dispose() {
    _newPassword.dispose();
    super.dispose();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await AuthService.instance.signOut();
      ////// AuthGate sees null user and switches back to the sign-in screen //////
    } catch (e) {
      _show(AuthService.friendlyMessage(e));
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _changePassword() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final newPassword = _newPassword.text;

    try {
      await AuthService.instance.changePassword(newPassword);
      _newPassword.clear();
      _show('Password updated.');
    } on FirebaseAuthException catch (e) {
      ////// login is too old: ask for current password, re-check it, then retry //////
      if (e.code == 'requires-recent-login') {
        await _reauthenticateAndRetry(newPassword);
      } else {
        _show(AuthService.friendlyMessage(e));
      }
    } catch (e) {
      _show(AuthService.friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reauthenticateAndRetry(String newPassword) async {
    final currentPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReauthDialog(),
    );

    ////// user hit Cancel //////
    if (currentPassword == null || currentPassword.isEmpty) {
      _show('Password not changed. Re-authentication was cancelled.');
      return;
    }

    try {
      await AuthService.instance.reauthenticate(currentPassword);
      await AuthService.instance.changePassword(
        newPassword,
      ); ////// the retry //////
      _newPassword.clear();
      _show('Password updated.');
    } catch (e) {
      _show(AuthService.friendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _signingOut ? null : _signOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Signed in as'),
            ////// show the current user's email //////
            Text(
              email ?? '(no email found)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Change password',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextFormField(
                    controller: _newPassword,
                    enabled: !_saving,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Enter a new password';
                      if (value.length < 6)
                        return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _changePassword,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update password'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _signingOut ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: Text(_signingOut ? 'Signing out...' : 'Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

////// pop-up that asks for the CURRENT password (owns + disposes its own controller) //////
class _ReauthDialog extends StatefulWidget {
  const _ReauthDialog();

  @override
  State<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<_ReauthDialog> {
  final _current = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm it\'s you'),
      content: TextField(
        controller: _current,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Current password'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _current.text),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
