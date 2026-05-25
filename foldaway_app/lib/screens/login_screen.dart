import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final String? initialMessage;
  final String? initialEmail;

  const LoginScreen({
    super.key,
    this.initialMessage,
    this.initialEmail,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();

  bool _isLoading = false;
  bool _isResending = false;

  String? _error;
  String? _successMessage;
  String? _verificationEmail;

  @override
  void initState() {
    super.initState();

    _successMessage = widget.initialMessage;
    _verificationEmail = widget.initialEmail;

    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _usernameController.text = widget.initialEmail!;
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    final result = await _apiService.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      context.go('/trips');
    } else {
      setState(() => _error = result.message);
    }
  }

  Future<void> _resendVerificationEmail() async {
    final email = _verificationEmail ?? _usernameController.text;

    if (email.trim().isEmpty) {
      setState(() => _error = 'Введіть email або імʼя користувача.');
      return;
    }

    setState(() {
      _isResending = true;
      _error = null;
      _successMessage = null;
    });

    final result = await _apiService.resendVerificationEmail(email);

    if (!mounted) return;

    setState(() {
      _isResending = false;

      if (result.success) {
        _successMessage = result.message;
      } else {
        _error = result.message;
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Foldaway',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Плануй подорожі легко',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              if (_successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.4)),
                  ),
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Імʼя користувача або email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _login(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Увійти'),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: const Text('Забули пароль?'),
              ),

              if (_verificationEmail != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isResending ? null : _resendVerificationEmail,
                  child: _isResending
                      ? const Text('Надсилаємо...')
                      : const Text('Надіслати лист підтвердження ще раз'),
                ),
              ],

              const SizedBox(height: 12),

              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('Немає акаунту? Зареєструватись'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}