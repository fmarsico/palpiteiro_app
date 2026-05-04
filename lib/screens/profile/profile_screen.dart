import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_colors.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String token;
  final void Function(AuthResult)? onSaved;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.token,
    this.onSaved,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _saving = false;

  // Toast state
  _ToastType? _toastType;
  String _toastMessage = '';
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _emailController = TextEditingController(text: widget.userEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  String get _initials {
    final source = _nameController.text.trim().isEmpty
        ? widget.userName.trim()
        : _nameController.text.trim();
    final parts = source.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }

  void _showToast(_ToastType type, String message) {
    _toastTimer?.cancel();
    setState(() {
      _toastType = type;
      _toastMessage = message;
    });
    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _toastType = null);
    });
  }

  void _dismissToast() {
    _toastTimer?.cancel();
    setState(() => _toastType = null);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showToast(_ToastType.error, 'Informe um nome válido.');
      return;
    }

    final trimmedName = _nameController.text.trim();
    final currentName = widget.userName.trim();

    if (trimmedName == currentName) {
      _showToast(_ToastType.error, 'Nenhuma alteração para salvar.');
      return;
    }

    setState(() => _saving = true);

    try {
      final result = await _authService.updateProfile(
        token: widget.token,
        name: trimmedName,
        email: widget.userEmail,
      );
      if (!mounted) return;
      widget.onSaved?.call(result);
      _showToast(_ToastType.success, 'Perfil atualizado!');
    } catch (e) {
      if (!mounted) return;
      _showToast(_ToastType.error, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildAvatar(),
                          const SizedBox(height: 28),
                          _buildNameField(),
                          const SizedBox(height: 16),
                          _buildEmailReadOnlyField(),
                          const SizedBox(height: 20),
                          _buildSaveButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Toast overlay
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: child,
              ),
              child: _toastType != null
                  ? Align(
                      key: ValueKey(_toastType),
                      alignment: Alignment.bottomCenter,
                      child: _buildToast(_toastType!, _toastMessage),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToast(_ToastType type, String message) {
    final isSuccess = type == _ToastType.success;

    final bgColor = isSuccess
        ? const Color(0xFF0C2A1A)
        : const Color(0xFF1A0C0C);
    final borderColor = isSuccess
        ? AppColors.green
        : AppColors.red.withAlpha(128);
    final iconBg = isSuccess
        ? AppColors.green.withAlpha(33)
        : AppColors.red.withAlpha(33);
    final titleColor = isSuccess ? AppColors.green : AppColors.red;
    final subtitleColor = isSuccess
        ? const Color(0xFF4A7C59)
        : const Color(0xFF4A3030);
    final subtitle = isSuccess
        ? 'Suas informações foram salvas.'
        : 'Verifique sua conexão e tente novamente.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isSuccess
                    ? Icon(Icons.check, size: 13, color: AppColors.green)
                    : Icon(Icons.info_outline, size: 13, color: AppColors.red),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSuccess ? 'Perfil atualizado!' : 'Erro ao salvar',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isSuccess ? subtitle : (message.isNotEmpty ? message : subtitle),
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _dismissToast,
              child: Text(
                '✕',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textDim,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.chevron_left,
              color: Color(0xFF8AB0C8),
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'MEUS DADOS',
            style: GoogleFonts.bebasNeue(
              fontSize: 22,
              color: AppColors.text,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.goldDim,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 3),
        ),
        child: Center(
          child: Text(
            _initials,
            style: GoogleFonts.dmSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Nome', AppColors.green),
        TextFormField(
          onChanged: (_) => setState(() {}),
          controller: _nameController,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            suffixIcon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.gold),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.gold.withAlpha(85)),
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
          ),
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) {
              return 'Informe seu nome';
            }
            if (trimmed.length < 2) {
              return 'Nome muito curto';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEmailReadOnlyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('E-mail', AppColors.textDim),
        TextField(
          controller: _emailController,
          readOnly: true,
          enabled: false,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            suffixIcon: const Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gerenciado pelo Firebase · não editável',
          style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textDim),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.goldDim,
          disabledBackgroundColor: AppColors.goldDim.withAlpha(150),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Salvar alterações',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _fieldLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

enum _ToastType { success, error }
