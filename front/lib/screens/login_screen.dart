import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_waveform.dart';
import '../services/api.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nameFocus = FocusNode();

  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _nameTouched = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) setState(() => _emailTouched = true);
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) setState(() => _passwordTouched = true);
    });
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) setState(() => _nameTouched = true);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _isLogin = !_isLogin;
      _emailTouched = false;
      _passwordTouched = false;
      _nameTouched = false;
      _errorMessage = null;
    });
    _formKey.currentState?.reset();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Введи email';
    final re = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.\w{2,}$');
    if (!re.hasMatch(v.trim())) return 'Некорректный email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Введи пароль';
    if (v.length < 6) return 'Минимум 6 символов';
    return null;
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Введи имя';
    if (v.trim().length < 2) return 'Слишком короткое (минимум 2 символа)';
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _emailTouched = true;
      _passwordTouched = true;
      if (!_isLogin) _nameTouched = true;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await Api.login(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      } else {
        await Api.register(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          name: _nameCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0, height: 280,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accentSuccess.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 150),
                    Center(
                      child: Text(
                        _isLogin ? 'Добро\nпожаловать' : 'Создать\nаккаунт',
                        style: GoogleFonts.inter(
                          color: cs.onSurface,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 28),
                    AnimatedWaveform(isPlaying: true, height: 44, barCount: 32),
                    const SizedBox(height: 28),

                    if (!_isLogin) ...[
                      _ValidatedField(
                        controller: _nameCtrl,
                        focusNode: _nameFocus,
                        hint: 'Твоё имя',
                        icon: Icons.person_outline_rounded,
                        validator: _validateName,
                        touched: _nameTouched,
                        onChanged: (_) { if (_nameTouched) setState(() {}); },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[а-яёА-ЯЁa-zA-Z\s\-]'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    _ValidatedField(
                      controller: _emailCtrl,
                      focusNode: _emailFocus,
                      hint: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      touched: _emailTouched,
                      onChanged: (_) { if (_emailTouched) setState(() {}); },
                    ),
                    const SizedBox(height: 12),

                    _ValidatedField(
                      controller: _passwordCtrl,
                      focusNode: _passwordFocus,
                      hint: _isLogin ? 'Пароль' : 'Придумай пароль (от 6 символов)',
                      icon: Icons.lock_outline_rounded,
                      validator: _validatePassword,
                      touched: _passwordTouched,
                      obscureText: _obscurePassword,
                      onChanged: (_) { if (_passwordTouched) setState(() {}); },
                      suffixAction: GestureDetector(
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: cs.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentDanger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.accentDanger.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.accentDanger, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(
                                  color: AppColors.accentDanger, fontSize: 13),
                            ),
                          ),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        onTap: _loading ? null : _submit,
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  _isLogin ? 'Войти' : 'Создать аккаунт',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: GestureDetector(
                        onTap: _switchMode,
                        child: RichText(
                          text: TextSpan(children: [
                            TextSpan(
                              text: _isLogin ? 'Нет аккаунта? ' : 'Уже есть аккаунт? ',
                              style: GoogleFonts.inter(
                                  color: cs.onSurfaceVariant, fontSize: 14),
                            ),
                            TextSpan(
                              text: _isLogin ? 'Зарегистрироваться' : 'Войти',
                              style: GoogleFonts.inter(
                                color: AppColors.accentSuccess,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidatedField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final bool touched;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final Widget? suffixAction;

  const _ValidatedField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    required this.validator,
    required this.touched,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.suffixAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final errorText = touched ? validator(controller.text) : null;
    final isValid = touched && errorText == null && controller.text.isNotEmpty;

    final borderColor = errorText != null
        ? AppColors.accentDanger
        : isValid
            ? AppColors.accentSuccess
            : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            onChanged: onChanged,
            obscureText: obscureText,
            style: GoogleFonts.inter(color: cs.onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                  color: cs.onSurfaceVariant, fontSize: 15),
              prefixIcon: Icon(
                icon,
                color: errorText != null
                    ? AppColors.accentDanger
                    : isValid
                        ? AppColors.accentSuccess
                        : cs.onSurfaceVariant,
                size: 20,
              ),
              suffixIcon: suffixAction ??
                  (touched && controller.text.isNotEmpty
                      ? Icon(
                          errorText != null
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          color: errorText != null
                              ? AppColors.accentDanger
                              : AppColors.accentSuccess,
                          size: 20,
                        )
                      : null),
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              border: InputBorder.none,
              filled: true,
              fillColor: cs.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.accentDanger, size: 14),
              const SizedBox(width: 5),
              Text(
                errorText,
                style: GoogleFonts.inter(
                  color: AppColors.accentDanger,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}
