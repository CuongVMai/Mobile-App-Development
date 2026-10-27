import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

////// Great-Grandparent /////
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fun Signup App',
      theme: ThemeData(primarySwatch: Colors.purple),
      home: const SignupPage(),
    );
  }
}

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  ////// The Global Key - acts like a remote control for the form /////
  final _formKey = GlobalKey<FormState>();

  ////// Controllers to track what the user types /////
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  ////// my tips, they're just saved in the app so no internet needed /////
  final Map<String, List<String>> tips = {
    'password_help': [
      'Use at least 12 characters if you can, longer passwords are harder to guess.',
      'Don\'t use the same password you use on other sites.',
      'Try mixing in some numbers and symbols.',
    ],
  };

  ////// the category is always password_help /////
  final String tipCategory = 'password_help';

  ////// stuff for the tip part /////
  bool isLoading = false;
  bool showError = false;
  bool simulateError = false;
  String? tipText;

  ////// runs when you press the tip button /////
  void getTip() async {
    ////// clear old stuff and show loading /////
    setState(() {
      isLoading = true;
      showError = false;
      tipText = null;
    });

    ////// fake loading for 1 second /////
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      isLoading = false;
      if (simulateError) {
        showError = true;
      } else {
        String tip = tips[tipCategory]![0];
        ////// making sure it's not over 240 characters /////
        if (tip.length > 240) {
          tip = tip.substring(0, 240);
        }
        tipText = tip;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      ////// Parent /////
      appBar: AppBar(
        title: const Text('Join Us Today for the Cash Money!'),
        backgroundColor: Colors.purple,
      ),
      ////// made it scroll so the tip stuff fits on the screen /////
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          ////// Child /////
          key: _formKey,
          child: Column(
            children: [
              const Text(
                'Create Your Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              ////// Name Field /////
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

              ////// Email Field /////
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

              ////// Password Field /////
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 24),

              ////// Sign Up Button /////
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Demo signup complete — your form passed validation!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                ),
                child: const Text('Sign Up', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 24),

              ////// tip button /////
              ElevatedButton(
                onPressed: getTip,
                child: const Text('Get a signup tip'),
              ),

              ////// turn this on to test the error /////
              SwitchListTile(
                title: const Text('Simulate error'),
                value: simulateError,
                onChanged: (value) {
                  setState(() {
                    simulateError = value;
                  });
                },
              ),

              ////// loading circle /////
              if (isLoading) const CircularProgressIndicator(),

              ////// shows the tip /////
              if (tipText != null) ...[
                const Text('Preset demo tip—not live AI.'),
                Text(tipText!),
              ],

              ////// shows the error and retry button /////
              if (showError) ...[
                const Text("Oops, the tip didn't load"),
                TextButton(onPressed: getTip, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
