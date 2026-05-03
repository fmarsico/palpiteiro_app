import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../models/pool_model.dart';
import '../../services/auth_service.dart';
import '../../services/pool_service.dart';
import '../auth/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String token;

  const DashboardScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.token,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _poolService = PoolService();
  final _authService = AuthService();

  int _currentTab = 0; // 0 = Bolões, 1 = Buscar
  List<Pool> _ownedPools = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPools();
  }

  Future<void> _loadPools() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final owned = await _poolService.getOwnedPools(
        userId: widget.userId,
        token: widget.token,
      );
      setState(() => _ownedPools = owned);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  String get _initials {
    final parts = widget.userName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return widget.userName.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _currentTab == 0 ? _buildPoolsTab() : _buildSearchTab(),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'PALPITEIRO',
              style: GoogleFonts.bebasNeue(
                fontSize: 22,
                color: AppColors.text,
                letterSpacing: 2,
              ),
            ),
          ),
          _buildAvatarMenu(),
        ],
      ),
    );
  }

  Widget _buildAvatarMenu() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      color: const Color(0xFF1A2D42),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: _onMenuSelected,
      itemBuilder: (_) => [
        _popupItem('perfil', Icons.person_outline, 'Meu Perfil', AppColors.text),
        _popupItem('editar', Icons.edit_outlined, 'Editar dados', AppColors.text),
        const PopupMenuDivider(height: 1),
        _popupItem('sair', Icons.logout, 'Sair', AppColors.red),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.goldDim,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 2),
        ),
        child: Center(
          child: Text(
            _initials,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 10),
          Text(label,
              style: GoogleFonts.dmSans(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Future<void> _onMenuSelected(String value) async {
    if (value == 'sair') {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  // ─── Bolões tab ───────────────────────────────────────────────────────────

  Widget _buildPoolsTab() {
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.card,
      onRefresh: _loadPools,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(13, 14, 13, 0),
            sliver: SliverToBoxAdapter(child: _sectionHeader()),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(child: _buildError())
          else if (_ownedPools.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildPoolCard(_ownedPools[i], isOwner: true),
                  childCount: _ownedPools.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            'MEUS BOLÕES',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showCreatePoolSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.goldDim,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Novo',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolCard(Pool pool, {required bool isOwner}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOwner ? AppColors.goldDim : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  pool.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _badge(isOwner),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Invite code
              Text(
                'Código',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(0x14BA7517),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Color(0x40BA7517)),
                ),
                child: Text(
                  pool.inviteCode,
                  style: GoogleFonts.dmMono(
                    fontSize: 12,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: pool.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Código copiado!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.copy_outlined,
                      size: 12, color: AppColors.textMuted),
                ),
              ),
              const Spacer(),
              // Ver bolão
              GestureDetector(
                onTap: () {
                  // TODO: navigate to pool detail
                },
                child: Row(
                  children: [
                    Text(
                      'Ver bolão',
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: AppColors.blue),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 14, color: AppColors.blue),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(bool isOwner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isOwner
            ? const Color(0x21BA7517)
            : const Color(0x211D9E75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOwner ? AppColors.goldDim : AppColors.green,
        ),
      ),
      child: Text(
        isOwner ? 'Dono' : 'Membro',
        style: GoogleFonts.dmSans(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isOwner ? AppColors.gold : AppColors.green,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined,
              size: 48, color: AppColors.textDim),
          const SizedBox(height: 12),
          Text(
            'Nenhum bolão ainda',
            style: GoogleFonts.dmSans(
                fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            'Crie seu primeiro bolão ou busque\no código de um amigo',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textDim),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _showCreatePoolSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.goldDim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Criar bolão',
                style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 40, color: AppColors.red),
          const SizedBox(height: 12),
          Text(_error ?? 'Erro ao carregar',
              style: GoogleFonts.dmSans(color: AppColors.red, fontSize: 14)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _loadPools,
            child: Text('Tentar novamente',
                style: GoogleFonts.dmSans(
                    color: AppColors.blue, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── Search tab ───────────────────────────────────────────────────────────

  Widget _buildSearchTab() {
    return _SearchPoolTab(userId: widget.userId, token: widget.token);
  }

  // ─── Bottom nav ───────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
      child: Row(
        children: [
          _navItem(
            index: 0,
            icon: Icons.grid_view_rounded,
            label: 'Bolões',
          ),
          _navItem(
            index: 1,
            icon: Icons.search_rounded,
            label: 'Buscar',
          ),
        ],
      ),
    );
  }

  Widget _navItem({required int index, required IconData icon, required String label}) {
    final active = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentTab = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: active ? AppColors.gold : AppColors.textDim),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: active ? AppColors.gold : AppColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Create pool sheet ────────────────────────────────────────────────────

  void _showCreatePoolSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePoolSheet(
        userId: widget.userId,
        token: widget.token,
        onCreated: (pool) {
          setState(() => _ownedPools.insert(0, pool));
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Create Pool Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _CreatePoolSheet extends StatefulWidget {
  final String userId;
  final String token;
  final void Function(Pool) onCreated;

  const _CreatePoolSheet({
    required this.userId,
    required this.token,
    required this.onCreated,
  });

  @override
  State<_CreatePoolSheet> createState() => _CreatePoolSheetState();
}

class _CreatePoolSheetState extends State<_CreatePoolSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _poolService = PoolService();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final pool = await _poolService.createPool(
        name: _nameController.text.trim(),
        ownerId: widget.userId,
        token: widget.token,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(pool);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bolão "${pool.name}" criado! Código: ${pool.inviteCode}'),
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Icon + title
              Container(
                width: 52,
                height: 52,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2A1A),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.green),
                ),
                child: const Icon(Icons.add, color: AppColors.green, size: 26),
              ),
              Text(
                'CRIAR BOLÃO',
                style: GoogleFonts.bebasNeue(
                    fontSize: 20, color: AppColors.text, letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              Text(
                'Defina um nome e compartilhe o código com seus amigos',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),
              // Name field
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'NOME DO BOLÃO',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              TextFormField(
                controller: _nameController,
                maxLength: 100,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Ex: Família Silva 🏆',
                  hintStyle: GoogleFonts.dmSans(
                      fontSize: 13, color: AppColors.textDim),
                  filled: true,
                  fillColor: AppColors.card,
                  counterStyle: GoogleFonts.dmSans(
                      fontSize: 10, color: AppColors.textDim),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.gold, width: 1.2),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Informe o nome do bolão'
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                'O código de convite será gerado automaticamente',
                style: GoogleFonts.dmSans(
                    fontSize: 10, color: AppColors.textDim),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _loading ? null : _create,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.goldDim,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : Text(
                            'Criar bolão',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Search Pool Tab
// ═══════════════════════════════════════════════════════════════════════════

class _SearchPoolTab extends StatefulWidget {
  final String userId;
  final String token;

  const _SearchPoolTab({required this.userId, required this.token});

  @override
  State<_SearchPoolTab> createState() => _SearchPoolTabState();
}

class _SearchPoolTabState extends State<_SearchPoolTab> {
  final _codeController = TextEditingController();
  final _poolService = PoolService();
  Pool? _foundPool;
  String? _searchError;
  bool _searching = false;
  bool _requesting = false;
  bool _requested = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _search(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.length != 8) {
      setState(() {
        _foundPool = null;
        _searchError = clean.isEmpty ? null : 'O código deve ter 8 caracteres';
      });
      return;
    }
    setState(() {
      _searching = true;
      _foundPool = null;
      _searchError = null;
      _requested = false;
    });
    try {
      final pool = await _poolService.findByInviteCode(
          inviteCode: clean, token: widget.token);
      setState(() => _foundPool = pool);
    } catch (_) {
      setState(() => _searchError = 'Nenhum bolão encontrado com esse código');
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _requestAccess() async {
    if (_foundPool == null) return;
    setState(() => _requesting = true);
    try {
      await _poolService.requestAccess(
        poolId: _foundPool!.id,
        userId: widget.userId,
        token: widget.token,
      );
      setState(() => _requested = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação enviada! Aguarde aprovação do dono.')),
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
      if (mounted) setState(() => _requesting = false);
    }
  }

  bool get _isValid => _foundPool != null;
  bool get _isInvalid => _searchError != null;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      child: Column(
        children: [
          // Icon + title
          Container(
            width: 52,
            height: 52,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.blue),
            ),
            child: const Icon(Icons.search_rounded,
                color: AppColors.blue, size: 26),
          ),
          Text(
            'ENTRAR NUM BOLÃO',
            style: GoogleFonts.bebasNeue(
                fontSize: 20, color: AppColors.text, letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          Text(
            'Digite o código de 8 caracteres\nrecebido pelo seu amigo',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
                fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          // Field label
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'CÓDIGO DE CONVITE',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: AppColors.green,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 5),
          // Code input
          TextField(
            controller: _codeController,
            maxLength: 8,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              color: _isValid
                  ? AppColors.green
                  : _isInvalid
                      ? AppColors.red
                      : AppColors.text,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••••',
              hintStyle: GoogleFonts.dmSans(
                  fontSize: 18, color: AppColors.textDim, letterSpacing: 4),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _isValid
                      ? AppColors.green
                      : _isInvalid
                          ? AppColors.red
                          : AppColors.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _isValid
                      ? AppColors.green
                      : _isInvalid
                          ? AppColors.red
                          : AppColors.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _isValid
                      ? AppColors.green
                      : _isInvalid
                          ? AppColors.red
                          : AppColors.gold,
                  width: 1.4,
                ),
              ),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.gold),
                      ),
                    )
                  : null,
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 6),
          if (_isValid)
            Text(
              'Bolão encontrado ✓',
              style: GoogleFonts.dmSans(
                  fontSize: 11, color: AppColors.green),
            )
          else if (_isInvalid)
            Text(
              'Verifique o código e tente novamente',
              style: GoogleFonts.dmSans(
                  fontSize: 11, color: AppColors.red.withAlpha(180)),
            ),
          const SizedBox(height: 14),
          // Result / Error card
          if (_foundPool != null) _buildResultCard()
          else if (_isInvalid) _buildErrorCard(),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _foundPool!.name,
            style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
          ),
          const SizedBox(height: 3),
          Text(
            'Código: ${_foundPool!.inviteCode}',
            style: GoogleFonts.dmSans(
                fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _requested || _requesting ? null : _requestAccess,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _requested
                    ? AppColors.border
                    : AppColors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: _requesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _requested
                            ? 'Solicitação enviada ✓'
                            : 'Solicitar entrada',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0C0C),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.red.withAlpha(85)),
      ),
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(
            'Código não encontrado',
            style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.red),
          ),
          const SizedBox(height: 3),
          Text(
            'Confirme o código com quem te convidou.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
                fontSize: 11,
                color: const Color(0xFF4A2A2A)),
          ),
        ],
      ),
    );
  }
}


