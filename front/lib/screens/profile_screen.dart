import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../core/theme_provider.dart';
import '../utils/formatters.dart';
import '../widgets/glass_card.dart';
import '../widgets/stat_card.dart';
import '../services/api.dart';
import 'tips_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _me;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _goals;
  Map<String, dynamic>? _weekly;

  List<String> _customFillers = [];
  final TextEditingController _fillerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fillerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        Api.getMe(),
        Api.getProfile(),
        Api.getGoals(),
        Api.getWeekly(),
      ]);
      final fillers = await Api.getCustomFillers();
      setState(() {
        _me = results[0];
        _profile = results[1];
        _goals = results[2];
        _weekly = results[3];
        _customFillers = fillers;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _editProfile({required String userName}) async {
    final cs = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController(text: userName);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Редактировать профиль',
          style: GoogleFonts.inter(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: _inputField(nameCtrl, 'Имя', Icons.person_outline_rounded, cs: cs),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Отмена',
              style: GoogleFonts.inter(color: cs.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Сохранить',
              style: GoogleFonts.inter(
                color: AppColors.accentSuccess,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Api.updateProfile(
        name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : null,
      );
      await _load();
      if (!mounted) return;
      _showSnack('Профиль обновлён', success: true);
    } catch (e) {
      debugPrint('ProfileScreen: updateProfile failed: $e');
      if (!mounted) return;
      _showSnack('Не удалось сохранить', success: false);
    }
  }

  Widget _inputField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? type,
    required ColorScheme cs,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: GoogleFonts.inter(color: cs.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: cs.onSurfaceVariant),
          prefixIcon: Icon(icon, color: cs.onSurfaceVariant, size: 20),
          filled: true,
          fillColor: cs.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );

  void _showSnack(String text, {required bool success}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          color: success ? AppColors.accentSuccess : Colors.white,
          size: 18,
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            color: success ? cs.onSurface : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
      backgroundColor: success ? cs.surface : AppColors.accentDanger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _addFiller() async {
    final word = _fillerCtrl.text.trim().toLowerCase();
    if (word.isEmpty) return;
    try {
      final updated = await Api.addCustomFiller(word);
      setState(() => _customFillers = updated);
      _fillerCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), success: false);
    }
  }

  Future<void> _removeFiller(String word) async {
    try {
      final updated = await Api.removeCustomFiller(word);
      setState(() => _customFillers = updated);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), success: false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentSuccess),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.accentDanger, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              GlassButton(
                onTap: _load,
                child: Center(
                  child: Text(
                    'Повторить',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    final me = _me ?? {};
    final p = _profile ?? {};
    final g = _goals ?? {};
    final w = _weekly ?? {};

    final userEmail = (me['email'] as String?) ?? '';
    final userName = (p['name'] as String?) ?? '';
    final streak = (p['streak'] as int?) ?? 0;
    final totalRecs = (p['total_recordings'] as int?) ?? 0;
    final bestScore = (p['best_score'] as int?) ?? 0;
    final avgScore = (p['avg_score'] as int?) ?? 0;

    final currentScore = (g['current_score'] as int?) ?? 0;

    final weeklyCount = (w['recordings_count'] as int?) ?? 0;
    final weeklyAvg = (w['avg_score'] as int?) ?? 0;
    final weeklyBest = (w['best_score'] as int?) ?? 0;
    final improvement = (w['improvement'] as int?) ?? 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            elevation: 0,
            pinned: false,
            forceElevated: false,
            titleSpacing: 20,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Профиль',
              style: GoogleFonts.inter(
                color: cs.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => _editProfile(userName: userName),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF13223F)
                          : const Color(0xFFE8EEF7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      color: cs.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Column(children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.accentSuccess, AppColors.accentBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: userName.isNotEmpty
                          ? Text(
                              userName[0].toUpperCase(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            )
                          : const Icon(Icons.person_rounded,
                              color: Colors.white, size: 44),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    userName.isNotEmpty ? userName : 'Пользователь',
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  if (userEmail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: GoogleFonts.inter(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],

                  if (streak > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accentWarning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.accentWarning.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🔥', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          '$streak ${pluralizeDays(streak)} подряд',
                          style: GoogleFonts.inter(
                            color: AppColors.accentWarning,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 10),
                ]),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    StatCard(
                      label: 'Всего записей',
                      value: '$totalRecs',
                      icon: Icons.mic_rounded,
                      color: AppColors.accentBlue,
                    ),
                    StatCard(
                      label: 'Лучший балл',
                      value: '$bestScore',
                      icon: Icons.emoji_events_rounded,
                      color: AppColors.accentSuccess,
                    ),
                    StatCard(
                      label: 'Средний балл',
                      value: '$avgScore',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.accentSuccess,
                    ),
                    StatCard(
                      label: 'Последний балл',
                      value: '$currentScore',
                      icon: Icons.grade_rounded,
                      color: AppColors.accentWarning,
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                GlassCard(
                  borderColor: AppColors.accentBlue.withValues(alpha: 0.2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bar_chart_rounded,
                              color: AppColors.accentBlue, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Итоги недели',
                          style: GoogleFonts.inter(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        _WeekStatItem(
                            label: 'Записей',
                            value: '$weeklyCount',
                            color: AppColors.accentBlue),
                        _WeekStatItem(
                            label: 'Средний',
                            value: '$weeklyAvg',
                            color: AppColors.accentWarning),
                        _WeekStatItem(
                            label: 'Лучший',
                            value: '$weeklyBest',
                            color: AppColors.accentSuccess),
                        _WeekStatItem(
                          label: 'Рост',
                          value:
                              '${improvement >= 0 ? '+' : ''}$improvement',
                          color: improvement >= 0
                              ? AppColors.accentSuccess
                              : AppColors.accentDanger,
                        ),
                      ]),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                ListenableBuilder(
                  listenable: themeNotifier,
                  builder: (context, _) => GlassCard(
                    borderColor: AppColors.accentWarning.withValues(alpha: 0.2),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentWarning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          themeNotifier.isLight
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: AppColors.accentWarning,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Светлая тема',
                              style: GoogleFonts.inter(
                                color: cs.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              themeNotifier.isLight
                                  ? 'Включена'
                                  : 'Выключена',
                              style: GoogleFonts.inter(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: themeNotifier.isLight,
                        onChanged: (_) => themeNotifier.toggle(),
                        activeColor: AppColors.accentSuccess,
                        activeTrackColor:
                            AppColors.accentSuccess.withValues(alpha: 0.3),
                        inactiveThumbColor: cs.onSurfaceVariant,
                        inactiveTrackColor:
                            cs.onSurfaceVariant.withValues(alpha: 0.2),
                      ),
                    ]),
                  ),
                ),

                const SizedBox(height: 12),

                _CustomFillersCard(
                  fillers: _customFillers,
                  controller: _fillerCtrl,
                  onAdd: _addFiller,
                  onRemove: _removeFiller,
                ),

                const SizedBox(height: 12),
                GlassCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TipsScreen()),
                  ),
                  borderColor: AppColors.accentSuccess.withValues(alpha: 0.2),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentSuccess.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lightbulb_rounded,
                          color: AppColors.accentSuccess, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Советы и упражнения',
                            style: GoogleFonts.inter(
                              color: cs.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Упражнения для улучшения речи',
                            style: GoogleFonts.inter(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant, size: 20),
                  ]),
                ),

                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _logout,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.accentDanger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.accentDanger.withValues(alpha: 0.25)),
                    ),
                    child: Center(
                      child: Text(
                        'Выйти из аккаунта',
                        style: GoogleFonts.inter(
                          color: AppColors.accentDanger,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomFillersCard extends StatelessWidget {
  final List<String> fillers;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final void Function(String) onRemove;

  const _CustomFillersCard({
    required this.fillers,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      borderColor: AppColors.accentDanger.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentDanger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.block_rounded,
                  color: AppColors.accentDanger, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Мои слова-паразиты',
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Учитываются в анализе как статические',
                    style: GoogleFonts.inter(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          if (fillers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: fillers
                  .map((w) => Chip(
                        label: Text(
                          w,
                          style: GoogleFonts.inter(
                            color: cs.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        deleteIcon: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        onDeleted: () => onRemove(w),
                        backgroundColor: cs.onSurface.withValues(alpha: 0.07),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: GoogleFonts.inter(color: cs.onSurface, fontSize: 13),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAdd(),
                decoration: InputDecoration(
                  hintText: 'Добавить слово...',
                  hintStyle:
                      GoogleFonts.inter(color: cs.onSurfaceVariant, fontSize: 13),
                  filled: true,
                  fillColor: cs.onSurface.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentDanger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded,
                    color: AppColors.accentDanger, size: 20),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _WeekStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _WeekStatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(children: [
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: cs.onSurfaceVariant,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}
