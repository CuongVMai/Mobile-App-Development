import 'package:flutter/material.dart';

import 'success_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  ////// form key /////
  final _formKey = GlobalKey<FormState>();

  ////// controllers for the text boxes /////
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _dateController = TextEditingController();

  ////// creature they pick /////
  String? _selectedCreatureType;

  ////// true = dots false = letters /////
  bool _obscurePassword = true;

  DateTime? _birthDate;

  bool _submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    ////// wait 2 sec /////
    await Future.delayed(const Duration(seconds: 2));

    ////// check if still on the screen /////
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SuccessScreen(
          userName: _nameController.text.trim(),
          creatureType: _selectedCreatureType!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Us Today for the Cash Money!'),
        backgroundColor: Colors.purple,
      ),
      ////// scroll so it doesnt overflow /////
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                'Create Your Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              ////// name /////
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Fill in your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              ////// email /////
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Fill in your email';
                  }
                  if (!value.contains('@')) {
                    return 'That email needs an @';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              ////// password + eye button /////
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Fill in a password';
                  }
                  if (value.length < 6) {
                    return 'Too short, make it at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              ////// creature dropdown /////
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Creature Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Ghost', child: Text('Ghost')),
                  DropdownMenuItem(value: 'Bat', child: Text('Bat')),
                  DropdownMenuItem(
                    value: 'Black Cat',
                    child: Text('Black Cat'),
                  ),
                  DropdownMenuItem(
                    value: 'Pumpkin Spirit',
                    child: Text('Pumpkin Spirit'),
                  ),
                  DropdownMenuItem(value: 'Witch', child: Text('Witch')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCreatureType = value;
                  });
                },
                validator: (value) => value == null ? 'Pick a creature' : null,
              ),
              const SizedBox(height: 16),

              ////// birth date /////
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Birth Date',
                  prefixIcon: Icon(Icons.cake),
                  border: OutlineInputBorder(),
                ),
                validator: (_) =>
                    _birthDate == null ? 'Pick your birth date' : null,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2008),
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(), ////// cant pick future /////
                  );
                  if (picked != null) {
                    setState(() {
                      _birthDate = picked;
                      _dateController.text =
                          '${picked.month}/${picked.day}/${picked.year}';
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              ////// register button, null = disabled /////
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Register Creature',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
