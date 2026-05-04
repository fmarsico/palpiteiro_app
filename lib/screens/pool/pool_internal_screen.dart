import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_colors.dart';
import '../../models/match_model.dart';
import '../../models/member_model.dart';
import '../../models/pool_model.dart';
import '../../models/ranking_model.dart';
import '../../services/pool_internal_service.dart';

class PoolInternalScreen extends StatefulWidget {
  final Pool pool;
  final String currentUserId;
  final String currentUserName;
  final String token;

  const PoolInternalScreen({
    super.key,
    required this.pool,
    required this.currentUserId,
    required this.currentUserName,
    required this.token,
  });

  @override
  State<PoolInternalScreen> createState() => _PoolInternalScreenState();
}

class _PoolInternalScreenState extends State<PoolInternalScreen> {
  final _service = PoolInternalService();
  int _currentTab = 0;

  bool get _isOwner => widget.pool.ownerId == widget.currentUserId;

  // ─── Palpites state ─────────────────────────────────────────────────────────
  List<Match> _matches = [];
  bool _matchesLoading = true;
  String? _matchesError;
  bool _savingGuesses = false;
  String? _saveError;
  bool _saveSuccess = false;
  String _selectedPhase = 'Todos';
  final Map<String, TextEditingController> _homeCtrl = {};
  final Map<String, TextEditingController> _awayCtrl = {};

  // ─── Ranking state ───────────────────────────────────────────────────────────
  List<RankingEntry> _ranking = [];
  bool _rankingLoading = false;
  bool _rankingLoaded = false;
  String? _rankingError;

  // ─── Members state ───────────────────────────────────────────────────────────
  List<PoolMember> _members = [];
  List<PoolMember> _pendingRequests = [];
  bool _membersLoading = false;
  bool _membersLoaded = false;
  String? _membersError;

  @override
  void initState() {
    super.initState();
    _loadPalpitesData();
  }

  @override
  void dispose() {
    for (final c in _homeCtrl.values) {
      c.dispose();
    }
    for (final c in _awayCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadPalpitesData() async {
    setState(() {
      _matchesLoading = true;
      _matchesError = null;
    });
    try {
      final matches =
          await _service.getMatches(poolId: widget.pool.id, token: widget.token);

      List<Guess> guesses = [];
      try {
        guesses = await _service.getGuesses(
            poolId: widget.pool.id, token: widget.token);
      } catch (_) {}

      // Merge guesses into matches
      final guessMap = {for (final g in guesses) g.matchId: g};
      for (final m in matches) {
        m.myGuess = guessMap[m.id];
      }

      // Create controllers
      for (final m in matches) {
        _homeCtrl[m.id] =
            TextEditingController(text: m.myGuess?.homeScore?.toString() ?? '');
        _awayCtrl[m.id] =
            TextEditingController(text: m.myGuess?.awayScore?.toString() ?? '');
      }

      setState(() => _matches = matches);
    } catch (e) {
      setState(() =>
          _matchesError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _matchesLoading = false);
    }
  }

  Future<void> _loadRanking() async {
    if (_rankingLoaded) return;
    setState(() {
      _rankingLoading = true;
      _rankingError = null;
    });
    try {
      final data = await _service.getRanking(
          poolId: widget.pool.id, token: widget.token);
      setState(() {
        _ranking = data;
        _rankingLoaded = true;
      });
    } catch (e) {
      setState(() =>
          _rankingError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _rankingLoading = false);
    }
  }

  Future<void> _loadMembers() async {
    if (_membersLoaded) return;
    setState(() {
      _membersLoading = true;
      _membersError = null;
    });
    try {
      final data = await _service.getMembers(
          poolId: widget.pool.id, token: widget.token);
      setState(() {
        _members = data.members;
        _pendingRequests = data.pending;
        _membersLoaded = true;
      });
    } catch (e) {
      setState(() =>
          _membersError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _membersLoading = false);
    }
  }

  Future<void> _saveGuesses() async {
    final guesses = <Guess>[];
    for (final m in _matches) {
      if (m.isLocked) continue;
      final homeText = _homeCtrl[m.id]?.text.trim() ?? '';
      final awayText = _awayCtrl[m.id]?.text.trim() ?? '';
      if (homeText.isEmpty && awayText.isEmpty) continue;
      final home = int.tryParse(homeText);
      final away = int.tryParse(awayText);
      if (home == null || away == null) continue;
      guesses.add(Guess(matchId: m.id, homeScore: home, awayScore: away));
    }

    if (guesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha ao menos um palpite para salvar.')),
      );
      return;
    }

    setState(() {
      _savingGuesses = true;
      _saveError = null;
      _saveSuccess = false;
    });

    try {
      await _service.saveGuesses(
        poolId: widget.pool.id,
        guesses: guesses,
        token: widget.token,
      );
      setState(() => _saveSuccess = true);
    } catch (e) {
      setState(() =>
          _saveError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _savingGuesses = false);
    }
  }

  Future<void> _approveRequest(PoolMember member) async {
    try {
      await _service.approveRequest(
          poolId: widget.pool.id,
          requesterId: member.userId,
          token: widget.token);
      setState(() {
        _pendingRequests.remove(member);
        _members.add(PoolMember(
          userId: member.userId,
          name: member.name,
          isOwner: false,
          status: MemberStatus.approved,
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.red,
        ));
      }
    }
  }

  Future<void> _rejectRequest(PoolMember member) async {
    try {
      await _service.rejectRequest(
          poolId: widget.pool.id,
          requesterId: member.userId,
          token: widget.token);
      setState(() => _pendingRequests.remove(member));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.red,
        ));
      }
    }
  }

  Future<void> _removeMember(PoolMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Remover membro?',
        message:
            '${member.name} será removido do bolão e perderá acesso aos palpites.',
        confirmLabel: 'Remover',
        isDestructive: true,
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.removeMember(
          poolId: widget.pool.id,
          memberId: member.userId,
          token: widget.token);
      setState(() => _members.remove(member));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.red,
        ));
      }
    }
  }

  // ─── Tab switch ──────────────────────────────────────────────────────────────

  void _switchTab(int index) {
    setState(() => _currentTab = index);
    if (index == 1) _loadRanking();
    if (index == 2) _loadMembers();
  }

  // ─── Phase filters ───────────────────────────────────────────────────────────

  List<String> get _phases {
    final seen = <String>{};
    for (final m in _matches) {
      seen.add(m.phase);
    }
    return ['Todos', ...seen];
  }

  List<Match> get _filteredMatches {
    if (_selectedPhase == 'Todos') return _matches;
    return _matches.where((m) => m.phase == _selectedPhase).toList();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildInnerNav(),
            Expanded(
              child: IndexedStack(
                index: _currentTab,
                children: [
                  _buildPalpitesTab(),
                  _buildRankingTab(),
                  _buildMembrosTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final memberCount =
        _membersLoaded ? '${_members.length} membros' : '...';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.chevron_left,
                size: 22, color: Color(0xFF8AB0C8)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.pool.name,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 18,
                    color: AppColors.text,
                    letterSpacing: 1.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$memberCount · ${widget.pool.inviteCode}',
                  style: GoogleFonts.dmSans(
                      fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildBadge(_isOwner),
        ],
      ),
    );
  }

  Widget _buildBadge(bool isOwner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOwner ? const Color(0x21BA7517) : const Color(0x211D9E75),
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

  // ─── Inner nav ───────────────────────────────────────────────────────────────

  Widget _buildInnerNav() {
    const labels = ['Palpites', 'Ranking', 'Membros'];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: List.generate(
          3,
          (i) => Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _switchTab(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _currentTab == i
                          ? AppColors.gold
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _currentTab == i
                        ? AppColors.gold
                        : AppColors.textDim,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PALPITES TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPalpitesTab() {
    if (_matchesLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_matchesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: AppColors.red),
            const SizedBox(height: 12),
            Text(_matchesError!,
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.red)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _loadPalpitesData,
              child: Text('Tentar novamente',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: AppColors.blue)),
            ),
          ],
        ),
      );
    }
    if (_matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚽', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('Nenhuma partida disponível',
                style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Text('As partidas aparecerão aqui quando cadastradas.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: AppColors.textDim)),
          ],
        ),
      );
    }

    final filtered = _filteredMatches;

    return Column(
      children: [
        // Phase chips
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _phases.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final phase = _phases[i];
              final active = phase == _selectedPhase;
              return GestureDetector(
                onTap: () => setState(() => _selectedPhase = phase),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: active ? AppColors.goldDim : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? AppColors.goldDim : AppColors.border,
                    ),
                  ),
                  child: Text(
                    phase,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: active ? Colors.white : AppColors.textMuted,
                      fontWeight: active
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Match list
        Expanded(
          child: RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.card,
            onRefresh: _loadPalpitesData,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _buildMatchCard(filtered[i]),
            ),
          ),
        ),
        // Save feedback
        if (_saveSuccess)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0C2A1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.green),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 16, color: AppColors.green),
                const SizedBox(width: 8),
                Text(
                  'Palpites salvos com sucesso!',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.green,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (_saveError != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0C0C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.red.withAlpha(128)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: AppColors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _saveError!,
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.red,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        // Save button
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            children: [
              GestureDetector(
                onTap: _savingGuesses ? null : _saveGuesses,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.goldDim,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_savingGuesses)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      else ...[
                        const Icon(Icons.save_outlined,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Salvar todos os palpites',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Palpites bloqueados automaticamente no início de cada jogo',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 10, color: AppColors.textDim),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(Match match) {
    final locked = match.isLocked;
    return Opacity(
      opacity: locked && !match.hasOfficialResult ? 0.65 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Match meta: date + phase tag
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Text(
                    _formatDate(match.matchDate),
                    style: GoogleFonts.dmSans(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      match.phase,
                      style: GoogleFonts.dmSans(
                          fontSize: 9, color: AppColors.textDim),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Teams row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Home team
                  Expanded(
                    child: Column(
                      children: [
                        Text(match.homeFlag,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          match.homeTeam,
                          style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: const Color(0xFF8AB0C8),
                              fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // Score inputs
                  Row(
                    children: [
                      _buildScoreBox(
                        controller: _homeCtrl[match.id],
                        isLocked: locked,
                        isFilled: (_homeCtrl[match.id]?.text ?? '').isNotEmpty,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '×',
                          style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDim),
                        ),
                      ),
                      _buildScoreBox(
                        controller: _awayCtrl[match.id],
                        isLocked: locked,
                        isFilled: (_awayCtrl[match.id]?.text ?? '').isNotEmpty,
                      ),
                    ],
                  ),
                  // Away team
                  Expanded(
                    child: Column(
                      children: [
                        Text(match.awayFlag,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          match.awayTeam,
                          style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: const Color(0xFF8AB0C8),
                              fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Official result row (when match is played)
            if (match.hasOfficialResult) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Resultado oficial: ',
                      style: GoogleFonts.dmSans(
                          fontSize: 9, color: AppColors.textMuted),
                    ),
                    Text(
                      '${match.officialHomeScore} × ${match.officialAwayScore}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                    if (match.myGuess?.points != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '+${match.myGuess!.points} pts ✓',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBox({
    required TextEditingController? controller,
    required bool isLocked,
    required bool isFilled,
  }) {
    final text = controller?.text ?? '';
    final borderColor = isFilled ? AppColors.gold : AppColors.border;
    final textColor = isFilled ? AppColors.gold : AppColors.text;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: isLocked
          ? Center(
              child: Text(
                text.isEmpty ? '—' : text,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            )
          : Center(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 2,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => setState(() {
                  _saveSuccess = false;
                  _saveError = null;
                }),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RANKING TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRankingTab() {
    if (_rankingLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_rankingError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: AppColors.red),
            const SizedBox(height: 12),
            Text(_rankingError!,
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.red)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                _rankingLoaded = false;
                _loadRanking();
              },
              child: Text('Tentar novamente',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: AppColors.blue)),
            ),
          ],
        ),
      );
    }
    if (!_rankingLoaded) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_ranking.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('Ranking ainda vazio',
                style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Text(
                'Assim que os jogos acontecerem o ranking será atualizado.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: AppColors.textDim)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.card,
      onRefresh: () async {
        _rankingLoaded = false;
        await _loadRanking();
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Table header
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                _thCell(w: 30, text: '#', color: AppColors.textDim),
                _thCell(flex: 1, text: 'Nome', color: AppColors.textDim),
                _thCell(w: 40, text: 'Pts', color: AppColors.textDim),
                _thCell(w: 30, text: '✓', color: AppColors.green),
                _thCell(w: 30, text: 'GR', color: AppColors.textMuted),
                _thCell(w: 30, text: 'MM', color: AppColors.blue),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 6),
          // Ranking rows
          ...List.generate(_ranking.length, (i) {
            final entry = _ranking[i];
            final isMe = entry.userId == widget.currentUserId;
            return _buildRankRow(entry, isMe);
          }),
          // Legend
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _legendItem('✓ Acertos exatos', AppColors.green),
              _legendItem('GR Fase de grupos', AppColors.textMuted),
              _legendItem('MM Mata-mata', AppColors.blue),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _thCell({
    double? w,
    int? flex,
    required String text,
    required Color color,
  }) {
    final content = Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.dmSans(
        fontSize: 9,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
    if (w != null) return SizedBox(width: w, child: content);
    return Expanded(child: content);
  }

  Widget _buildRankRow(RankingEntry entry, bool isMe) {
    final posWidget = _positionWidget(entry.position);
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      decoration: isMe
          ? BoxDecoration(
              color: const Color(0x14BA7517),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x30BA7517)),
            )
          : null,
      child: Row(
        children: [
          SizedBox(width: 30, child: Center(child: posWidget)),
          Expanded(
            child: Text(
              entry.name,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                color: isMe ? AppColors.gold : AppColors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${entry.points}',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isMe ? AppColors.gold : AppColors.text,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text('${entry.exactGuesses}',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: AppColors.green)),
          ),
          SizedBox(
            width: 30,
            child: Text('${entry.groupPoints}',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: AppColors.textMuted)),
          ),
          SizedBox(
            width: 30,
            child: Text('${entry.knockoutPoints}',
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.dmSans(fontSize: 12, color: AppColors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _positionWidget(int pos) {
    if (pos == 1) return const Text('🥇', style: TextStyle(fontSize: 16));
    if (pos == 2) return const Text('🥈', style: TextStyle(fontSize: 16));
    if (pos == 3) return const Text('🥉', style: TextStyle(fontSize: 16));
    return Text(
      '$pos',
      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 9, color: AppColors.textDim)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEMBROS TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMembrosTab() {
    if (_membersLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_membersError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: AppColors.red),
            const SizedBox(height: 12),
            Text(_membersError!,
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.red)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                _membersLoaded = false;
                _loadMembers();
              },
              child: Text('Tentar novamente',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: AppColors.blue)),
            ),
          ],
        ),
      );
    }
    if (!_membersLoaded) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.card,
      onRefresh: () async {
        _membersLoaded = false;
        await _loadMembers();
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Pending requests (owner only)
          if (_isOwner && _pendingRequests.isNotEmpty) ...[
            _sectionLabel('Solicitações pendentes', count: _pendingRequests.length),
            const SizedBox(height: 8),
            ..._pendingRequests
                .map((m) => _buildPendingRow(m))
                ,
            const SizedBox(height: 8),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
          ],
          // Members
          _sectionLabel('Membros'),
          const SizedBox(height: 8),
          if (_members.isEmpty)
            Center(
              child: Text(
                'Nenhum membro ainda.',
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: AppColors.textDim),
              ),
            )
          else
            ..._members.map((m) => _buildMemberRow(m)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, {int? count}) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPendingRow(PoolMember member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.red.withAlpha(50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              member.name,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _approveRequest(member),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Aprovar',
                style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _rejectRequest(member),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.red),
              ),
              child: Text(
                'Rejeitar',
                style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(PoolMember member) {
    final isMe = member.userId == widget.currentUserId;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isMe
              ? const Color(0x40BA7517)
              : member.isOwner
                  ? const Color(0x30BA7517)
                  : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              member.name,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: (isMe || member.isOwner) ? AppColors.gold : AppColors.text,
              ),
            ),
          ),
          if (member.isOwner)
            _buildBadge(true)
          else if (_isOwner && !isMe)
            GestureDetector(
              onTap: () => _removeMember(member),
              child: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.red),
            ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d/$m · ${h}h$min';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Confirm Dialog
// ═══════════════════════════════════════════════════════════════════════════

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppColors.red.withAlpha(38)
                    : AppColors.gold.withAlpha(38),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDestructive
                      ? AppColors.red.withAlpha(76)
                      : AppColors.gold.withAlpha(76),
                ),
              ),
              child: Icon(
                isDestructive ? Icons.delete_outline : Icons.warning_outlined,
                size: 22,
                color: isDestructive ? AppColors.red : AppColors.gold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'Cancelar',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF8AB0C8)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isDestructive ? AppColors.red : AppColors.goldDim,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        confirmLabel,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

