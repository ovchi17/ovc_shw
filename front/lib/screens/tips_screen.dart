import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/colors.dart';
import '../widgets/glass_card.dart';
import '../services/api.dart';

const _kCacheKey = 'tips_cache_v1';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  int _selectedCategory = 0;
  bool _loading = true;
  bool _fromCache = false;
  String? _error;
  List<_Tip> _tips = [];

  final _categories = ['Все', 'Паразиты', 'Темп', 'Паузы', 'Лексика', 'Синтаксис'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await Api.getTips();
      final parsed = _parseTips(data);
      if (parsed.isNotEmpty) {
        await _saveCache(data);
        if (mounted) {
          setState(() { _tips = parsed; _fromCache = false; _loading = false; });
        }
        return;
      }
    } catch (e) {
      debugPrint('TipsScreen: getTips failed, will try cache: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final parsed = _parseTips(data);
        if (mounted) {
          setState(() { _tips = parsed; _fromCache = true; _loading = false; });
        }
        return;
      }
    } catch (e) {
      debugPrint('TipsScreen: cache read failed: $e');
    }

    if (mounted) {
      setState(() { _error = 'Нет соединения и кэша'; _loading = false; });
    }
  }

  Future<void> _saveCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheKey, jsonEncode(data));
    } catch (e) {
      debugPrint('TipsScreen: cache write failed: $e');
    }
  }

  List<_Tip> _parseTips(Map<String, dynamic> data) {
    final result = <_Tip>[];
    for (final t in (data['tips'] as List<dynamic>? ?? [])) {
      if (t is Map) {
        result.add(_Tip(
          category: _mapCategory((t['category'] ?? '').toString()),
          title: (t['title'] ?? '').toString(),
          description: (t['body'] ?? t['description'] ?? '').toString(),
          source: (t['source'] as String?) ?? '',
          icon: _iconForCategory((t['category'] ?? '').toString()),
          isExercise: false,
        ));
      }
    }
    for (final e in (data['exercises'] as List<dynamic>? ?? [])) {
      if (e is Map) {
        result.add(_Tip(
          category: _mapCategory((e['category'] ?? '').toString()),
          title: (e['title'] ?? '').toString(),
          description: (e['description'] ?? '').toString(),
          source: (e['source'] as String?) ?? '',
          icon: _iconForCategory((e['category'] ?? '').toString()),
          isExercise: true,
        ));
      }
    }
    return result;
  }

  String _mapCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'parasites': return 'Паразиты';
      case 'pauses': return 'Паузы';
      case 'tempo': return 'Темп';
      case 'lexical': return 'Лексика';
      case 'syntax': return 'Синтаксис';
      default: return 'Паразиты';
    }
  }

  IconData _iconForCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'parasites': return Icons.block_rounded;
      case 'pauses': return Icons.pause_circle_outline_rounded;
      case 'tempo': return Icons.speed_rounded;
      case 'lexical': return Icons.menu_book_rounded;
      case 'syntax': return Icons.account_tree_rounded;
      default: return Icons.lightbulb_rounded;
    }
  }

  List<_Tip> get _filtered {
    if (_selectedCategory == 0) return _tips;
    return _tips.where((t) => t.category == _categories[_selectedCategory]).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: cs.onSurfaceVariant, size: 18),
              ),
            ),
            title: Text(
              'Советы и упражнения',
              style: GoogleFonts.inter(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_fromCache)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.offline_bolt_rounded,
                            color: AppColors.accentWarning, size: 14),
                        const SizedBox(width: 6),
                        Text('Загружено из кэша',
                            style: GoogleFonts.inter(
                                color: AppColors.accentWarning, fontSize: 12)),
                        const Spacer(),
                        GestureDetector(
                          onTap: _load,
                          child: Text('Обновить',
                              style: GoogleFonts.inter(
                                  color: AppColors.accentBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),

                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (_, i) {
                      final selected = i == _selectedCategory;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.accentSuccess : cs.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: selected
                                ? null
                                : Border.all(
                                    color: cs.onSurface.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            _categories[i],
                            style: GoogleFonts.inter(
                              color: selected
                                  ? Colors.white
                                  : cs.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                              size: 40),
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: GoogleFonts.inter(
                                  color: cs.onSurfaceVariant, fontSize: 13),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _load,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.accentSuccess,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('Повторить',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._filtered.map((tip) => _TipCard(tip: tip)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatefulWidget {
  final _Tip tip;
  const _TipCard({required this.tip});

  @override
  State<_TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<_TipCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tip = widget.tip;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (tip.isExercise
                            ? AppColors.accentBlue
                            : AppColors.accentSuccess)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      tip.isExercise ? Icons.fitness_center_rounded : tip.icon,
                      color: tip.isExercise
                          ? AppColors.accentBlue
                          : AppColors.accentSuccess,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.title,
                        style: GoogleFonts.inter(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tip.category,
                              style: GoogleFonts.inter(
                                color: AppColors.accentBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (tip.isExercise)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentWarning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Упражнение',
                                style: GoogleFonts.inter(
                                  color: AppColors.accentWarning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: cs.onSurfaceVariant, size: 20),
                ),
              ],
            ),
          ),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Divider(color: cs.onSurface.withValues(alpha: 0.08), height: 1),
                const SizedBox(height: 12),
                Text(
                  tip.description,
                  style: GoogleFonts.inter(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                if (tip.source.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.science_outlined,
                          color: cs.onSurfaceVariant, size: 13),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          tip.source,
                          style: GoogleFonts.inter(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip {
  final String category;
  final String title;
  final String description;
  final String source;
  final IconData icon;
  final bool isExercise;

  const _Tip({
    required this.category,
    required this.title,
    required this.description,
    required this.source,
    required this.icon,
    required this.isExercise,
  });
}
