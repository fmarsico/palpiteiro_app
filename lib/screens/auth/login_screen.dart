import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  int _tabIndex = 0; // 0 = Entrar, 1 = Cadastrar

  // Login form
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscure = true;
  bool _loginLoading = false;

  // Register form
  final _registerFormKey = GlobalKey<FormState>();
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  bool _registerObscure = true;
  bool _registerLoading = false;
  String? _selectedTeam;
  bool _notifications = true;

  static const _brazilianTeams = [
    'Flamengo', 'Corinthians', 'Palmeiras', 'São Paulo', 'Santos',
    'Grêmio', 'Internacional', 'Atlético-MG', 'Cruzeiro', 'Fluminense',
    'Vasco', 'Botafogo', 'Outro',
  ];

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _loginLoading = true);
    try {
      final result = await _authService.login(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              userId: result.userId,
              userName: result.name,
              userEmail: result.email,
              token: result.token,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  Future<void> _doRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() => _registerLoading = true);
    try {
      final result = await _authService.register(
        name: _registerNameController.text.trim(),
        email: _registerEmailController.text.trim(),
        password: _registerPasswordController.text,
        favoriteTeam: _selectedTeam,
        notifications: _notifications,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              userId: result.userId,
              userName: result.name,
              userEmail: result.email,
              token: result.token,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _registerLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHero(),
            _buildTabBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: _tabIndex == 0 ? _buildLoginForm() : _buildRegisterForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero ────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: const BoxDecoration(
        color: AppColors.loginHeroBg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.goldDim,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: const Center(
              child: Icon(Icons.emoji_events_outlined,
                  color: Color(0xFFFAEEDA), size: 26),
            ),
          ),
          const SizedBox(height: 8),
          const Text('🇺🇸🇲🇽🇨🇦',
              style: TextStyle(fontSize: 15, letterSpacing: 3)),
          const SizedBox(height: 2),
          Text(
            'PALPITEIRO',
            style: GoogleFonts.bebasNeue(
              fontSize: 26,
              color: AppColors.text,
              letterSpacing: 3,
            ),
          ),
          Text(
            'COPA DO MUNDO 2026',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.green,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab bar ─────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTab('Entrar', 0),
          _buildTab('Cadastrar', 1),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.goldDim : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active
                  ? const Color(0xFFFAEEDA)
                  : AppColors.text.withAlpha(120),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Login form ───────────────────────────────────────────────────────────

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('E-mail'),
          _textField(
            controller: _loginEmailController,
            hint: 'seu@email.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
          ),
          _fieldLabel('Senha'),
          _passwordField(
            controller: _loginPasswordController,
            hint: '••••••••',
            obscure: _loginObscure,
            onToggle: () => setState(() => _loginObscure = !_loginObscure),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Senha muito curta' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  'Esqueceu a senha?',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.blue),
                ),
              ),
            ),
          ),
          _goldButton(label: 'Entrar', loading: _loginLoading, onTap: _doLogin),
          const SizedBox(height: 12),
          _divider('ou continue com'),
          const SizedBox(height: 10),
          _googleButton(),
          const SizedBox(height: 10),
          _termsText('Ao entrar você concorda com os '),
        ],
      ),
    );
  }

  // ─── Register form ────────────────────────────────────────────────────────

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Nome'),
          _textField(
            controller: _registerNameController,
            hint: 'Como quer ser chamado',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
          ),
          _fieldLabel('E-mail'),
          _textField(
            controller: _registerEmailController,
            hint: 'seu@email.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
          ),
          _fieldLabel('Senha'),
          _passwordField(
            controller: _registerPasswordController,
            hint: 'Mínimo 8 caracteres',
            obscure: _registerObscure,
            onToggle: () => setState(() => _registerObscure = !_registerObscure),
            validator: (v) =>
                (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
          ),
          _fieldLabel('Time do coração'),
          _teamDropdown(),
          const SizedBox(height: 4),
          _notificationsToggle(),
          _goldButton(
              label: 'Criar conta', loading: _registerLoading, onTap: _doRegister),
          const SizedBox(height: 10),
          _termsText('Ao criar conta você concorda com os '),
        ],
      ),
    );
  }

  // ─── Shared widgets ───────────────────────────────────────────────────────

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 10,
            color: AppColors.green,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textDim),
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      errorStyle: GoogleFonts.dmSans(fontSize: 10, color: AppColors.red),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text),
        decoration: _inputDecoration(hint),
        validator: validator,
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text),
        decoration: _inputDecoration(hint).copyWith(
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textDim,
              size: 18,
            ),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _teamDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedTeam,
        hint: Text(
          'Escolha seu time',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textDim),
        ),
        dropdownColor: AppColors.card,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text),
        icon: const Icon(Icons.keyboard_arrow_down,
            color: AppColors.green, size: 18),
        decoration: _inputDecoration('').copyWith(hintText: null),
        items: _brazilianTeams
            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
            .toList(),
        onChanged: (v) => setState(() => _selectedTeam = v),
      ),
    );
  }

  Widget _notificationsToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Notificações dos jogos',
            style: GoogleFonts.dmSans(
                fontSize: 12, color: const Color(0xFF8AB0C8)),
          ),
          GestureDetector(
            onTap: () => setState(() => _notifications = !_notifications),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 20,
              decoration: BoxDecoration(
                color: _notifications ? AppColors.green : AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _notifications
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goldButton({
    required String label,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.goldDim,
        disabledBackgroundColor: AppColors.goldDim.withAlpha(150),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    );
  }

  Widget _divider(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(text,
              style:
                  GoogleFonts.dmSans(fontSize: 11, color: AppColors.textDim)),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _googleButton() {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
                color: AppColors.red, shape: BoxShape.circle),
            child: const Center(
              child: Text('G',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Text('Entrar com Google',
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: const Color(0xFF8AB0C8))),
        ],
      ),
    );
  }

  Widget _termsText(String prefix) {
    return Center(
      child: Text.rich(
        TextSpan(
          text: prefix,
          style: GoogleFonts.dmSans(
              fontSize: 10, color: AppColors.textDim, height: 1.5),
          children: [
            TextSpan(
              text: 'Termos de uso',
              style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.blue),
            ),
            const TextSpan(text: ' e '),
            TextSpan(
              text: 'Privacidade',
              style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.blue),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

