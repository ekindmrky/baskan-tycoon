import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:presidento/logic/game_provider.dart';
import 'package:presidento/widgets/investment_menu_sheet.dart';
import 'package:presidento/widgets/league_standings_sheet.dart';
import 'package:presidento/widgets/trophy_room_sheet.dart';
import 'package:presidento/models/match_calendar.dart';
import 'package:presidento/models/random_event.dart';
import 'package:presidento/models/branch.dart';
import 'package:presidento/models/club.dart';
import 'main_menu_screen.dart';
import 'season_end_screen.dart';
import 'sponsor_selection_screen.dart';

// ---------------------------------------------------------------------------
// Renk yardımcısı
// ---------------------------------------------------------------------------
Color _hex(String hex, Color fallback) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return fallback;
  }
}

// ---------------------------------------------------------------------------
// DashboardScreen
// ---------------------------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController(viewportFraction: 0.88);
  int _currentPage = 0;
  int _dashboardMainTab =
      0; // 0 kulüp, 1 maçlar (fikstür), 2 tarihçe
  bool _isSimulating = false;

  /// Otomatik hafta ilerleme (Play / Pause).
  bool _autoPlaying = false;

  /// Eşzamanlı auto döngü örneklerini iptal eder.
  int _autoRunId = 0;

  /// Kalan haftaları tek seferde simüle eder (beta/test).
  bool _fastSkipping = false;

  /// Çift sponsor ekranı push'unu önler (didChangeDependencies yarışı).
  bool _sponsorNavInFlight = false;

  /// Otomatik mod göstergesi (opacity).
  late final AnimationController _autoBlinkCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Simülasyon spinner animasyonu
  late final AnimationController _spinCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  static const _branches = [
    CountryData.football,
    CountryData.basketball,
    CountryData.volleyball,
  ];

  static const _branchIcons = {
    CountryData.football: Icons.sports_soccer_rounded,
    CountryData.basketball: Icons.sports_basketball_rounded,
    CountryData.volleyball: Icons.sports_volleyball_rounded,
  };

  /// Branş ayırıcı için düşük doygunluklu vurgular (takım renklerinden bağımsız).
  static const _branchAccents = {
    CountryData.football: Color(0xFF2DD4BF),
    CountryData.basketball: Color(0xFF7DD3FC),
    CountryData.volleyball: Color(0xFFC4B5FD),
  };

  /// Beklenen üç branş kartı hazır değilse yükleme göster (kısmi / bozuk kayıt).
  static bool _clubBranchesReady(Club club) {
    try {
      final br = club.branches;
      if (br.length < _branches.length) return false;
      for (final name in _branches) {
        final matches = br.where((b) => b.name == name).toList();
        if (matches.length != 1) return false;
        final bb = matches.first;
        if (bb.budget.isNaN ||
            bb.budget.isInfinite ||
            bb.successRate.isNaN ||
            bb.successRate.isInfinite) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gp = context.read<GameProvider>();
    if (gp.needsSponsorSelection && !_sponsorNavInFlight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _navigateToSponsorSelection();
      });
    }
  }

  Future<void> _navigateToSponsorSelection() async {
    if (_sponsorNavInFlight || !mounted) return;
    final gp = context.read<GameProvider>();
    if (!gp.needsSponsorSelection) return;

    _sponsorNavInFlight = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const SponsorSelectionScreen()),
      );
    } finally {
      _sponsorNavInFlight = false;
    }
  }

  @override
  void dispose() {
    _autoRunId++; // Bekleyen auto döngülerini iptal et
    _pageCtrl.dispose();
    _spinCtrl.dispose();
    _autoBlinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyWeekSilent() async {
    if (!mounted) return;
    final gp = context.read<GameProvider>();
    gp.advanceWeek();
    if (gp.pendingChoiceEvent != null) {
      gp.resolveChoiceEvent(0);
    }
    if (!mounted) return;
    await Future<void>.delayed(Duration.zero);
    setState(() {});
  }

  void _toggleAutoPlay(GameProvider gp) {
    if (gp.needsSponsorSelection || gp.isSeasonOver || _isSimulating) return;
    if (_fastSkipping) return;

    if (_autoPlaying) {
      _autoRunId++;
      _autoBlinkCtrl.stop();
      _autoBlinkCtrl.reset();
      setState(() => _autoPlaying = false);
      return;
    }

    _autoRunId++;
    final runId = _autoRunId;
    setState(() => _autoPlaying = true);
    _autoBlinkCtrl.repeat(reverse: true);
    unawaited(_runAutoAdvanceLoop(runId));
  }

  Future<void> _runAutoAdvanceLoop(int runId) async {
    while (mounted &&
        _autoPlaying &&
        runId == _autoRunId) {
      final gp0 = context.read<GameProvider>();
      if (gp0.isSeasonOver || gp0.needsSponsorSelection) {
        _stopAutoAdvanceAndBlink();
        if (mounted && gp0.isSeasonOver) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SeasonEndScreen()),
          );
        }
        break;
      }

      await _applyWeekSilent();
      if (!mounted || !_autoPlaying || runId != _autoRunId) return;

      final gp1 = context.read<GameProvider>();
      if (gp1.isSeasonOver) {
        _stopAutoAdvanceAndBlink();
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SeasonEndScreen()),
        );
        break;
      }

      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || !_autoPlaying || runId != _autoRunId) return;
    }
  }

  void _stopAutoAdvanceAndBlink() {
    _autoRunId++;
    _autoBlinkCtrl.stop();
    _autoBlinkCtrl.reset();
    setState(() => _autoPlaying = false);
  }

  Future<void> _promptFastFinishSeason(GameProvider gp) async {
    if (_fastSkipping ||
        _autoPlaying ||
        gp.isSeasonOver ||
        gp.needsSponsorSelection ||
        _isSimulating) {
      return;
    }

    final go = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF111C33),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.flash_on_rounded,
                color: Theme.of(context).colorScheme.primary, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sezonu hızlı bitir',
                style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Kalan lig haftaları arka planda hızlıca simüle edilir; seçimli '
          'olaylarda ilk seçenek kullanılır. Senaryo doğrudan sezon özeti ile '
          'biter. Devam edilsin mi?',
          style: GoogleFonts.rajdhani(
            color: const Color(0xFF94A3B8),
            height: 1.45,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child:
                Text('İptal', style: GoogleFonts.rajdhani(color: const Color(0xFF94A3B8))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(
              'Hızlı bitir',
              style: GoogleFonts.rajdhani(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    _autoRunId++;

    setState(() => _fastSkipping = true);
    try {
      var iterations = 0;
      var g = context.read<GameProvider>();

      while (mounted &&
          iterations < 520 &&
          !g.needsSponsorSelection &&
          !g.isSeasonOver) {
        g.advanceWeek();
        if (g.pendingChoiceEvent != null) {
          g.resolveChoiceEvent(0);
        }
        iterations++;

        if (!mounted) return;
        if (iterations % 3 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        if (mounted) setState(() {});
      }

      if (!mounted) return;
      final gFinal = context.read<GameProvider>();
      if (!gFinal.isSeasonOver || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SeasonEndScreen()),
      );
    } finally {
      if (mounted) setState(() => _fastSkipping = false);
    }
  }

  // -------------------------------------------------------------------------
  // Hafta ilerleme aksiyonu — animasyon → seçimli olay → rapor / sezon sonu
  // -------------------------------------------------------------------------
  Future<void> _onAdvanceWeek(GameProvider gp) async {
    if (_isSimulating ||
        _autoPlaying ||
        _fastSkipping ||
        gp.isSeasonOver ||
        gp.needsSponsorSelection) {
      return;
    }
    setState(() => _isSimulating = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    gp.advanceWeek();
    final presidentEvent = gp.pendingPresidentEvent;
    setState(() => _isSimulating = false);

    if (!mounted) return;

    if (presidentEvent != null) {
      await _showPresidentEventDialog(presidentEvent, gp);
      if (!mounted) return;
    }

    if (gp.isSeasonOver) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SeasonEndScreen()),
      );
    } else {
      _showWeeklyReport(gp);
    }
  }

  Future<void> _showPresidentEventDialog(
      RandomEvent event, GameProvider gp) async {
    final (iconData, eventColor) = _presidentEventVisuals(event.kind);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: const Color(0xFF111C33),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: eventColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(iconData, color: eventColor, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OLAY VAR!',
                          style: GoogleFonts.rajdhani(
                            fontSize: 11,
                            color: eventColor,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          event.title,
                          style: GoogleFonts.rajdhani(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                event.narrative,
                style: GoogleFonts.rajdhani(
                  fontSize: 14, color: const Color(0xFF8A9BB8), height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              // Seçenek A
              _randomEventChoiceButton(
                option: event.optionA,
                color: const Color(0xFF69F0AE),
                onTap: () {
                  Navigator.pop(dialogCtx);
                  gp.resolveChoiceEvent(0);
                },
              ),
              const SizedBox(height: 10),
              // Seçenek B
              _randomEventChoiceButton(
                option: event.optionB,
                color: const Color(0xFFFF5252),
                onTap: () {
                  Navigator.pop(dialogCtx);
                  gp.resolveChoiceEvent(1);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _randomEventChoiceButton({
    required RandomEventOption option,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              option.label,
              style: GoogleFonts.rajdhani(
                fontSize: 16, fontWeight: FontWeight.w800, color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              option.description,
              style: GoogleFonts.rajdhani(
                fontSize: 12, color: const Color(0xFF8A9BB8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static (IconData, Color) _presidentEventVisuals(RandomEventKind kind) =>
      switch (kind) {
        RandomEventKind.sponsorship => (
            Icons.handshake_rounded,
            const Color(0xFF4FC3F7)
          ),
        RandomEventKind.bonusDistribution => (
            Icons.payments_rounded,
            const Color(0xFF69F0AE)
          ),
        RandomEventKind.scandal => (
            Icons.warning_amber_rounded,
            const Color(0xFFFF5252)
          ),
        RandomEventKind.citySupport => (
            Icons.location_city_rounded,
            const Color(0xFF69F0AE)
          ),
        RandomEventKind.youngTalent => (
            Icons.sports_soccer_rounded,
            const Color(0xFFFFBF00)
          ),
        RandomEventKind.fanBoycott => (
            Icons.group_off_rounded,
            const Color(0xFFFF5252)
          ),
        RandomEventKind.mediaAttention => (
            Icons.tv_rounded,
            const Color(0xFF4FC3F7)
          ),
        RandomEventKind.rivalryHype => (
            Icons.local_fire_department_rounded,
            const Color(0xFFFFBF00)
          ),
        RandomEventKind.infrastructureIssue => (
            Icons.construction_rounded,
            const Color(0xFFFF5252)
          ),
        RandomEventKind.sponsorCrisis => (
            Icons.money_off_rounded,
            const Color(0xFFFF5252)
          ),
      };

  void _showWeeklyReport(GameProvider gp) {
    final primary = _hex(
      gp.currentClub?.primaryColor ?? '',
      const Color(0xFFFFBF00),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _WeeklyReportSheet(
        results:      gp.lastWeekResults,
        cupResults:   gp.lastCupResults,
        summary:      gp.lastEconomySummary,
        week:         gp.currentWeek - 1,
        primary:      primary,
        branchIcons:  _branchIcons,
        branchAccents: _branchAccents,
      ),
    );
  }

  Future<void> _promptFacilityNaming(
    BuildContext ctx,
    GameProvider gp,
    String branchName,
  ) async {
    final label = gp.facilityAcademyLabel(branchName);
    await showDialog<void>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF111C33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.sell_rounded, color: Color(0xFFFFBF00), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tesis isim hakkı',
                style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          label != null
              ? 'Bu branşta tesis adı satışı zaten yapılmış: "$label".'
              : '$branchName tesisleri Sınıf A seviyesinde. Bir markanın '
                  'Arena / kompleks isim hakkını tek seferlik devrederek büyük '
                  'nakit enjekte edebilirsiniz (ör. Trendyol Arena). Ödeme '
                  'liginize göre milyonlarca € olabilir; itibarınız biraz '
                  'artar. Bu seçenek branşta yalnızca bir kez kullanılabilir.',
          style: GoogleFonts.rajdhani(
            fontSize: 14,
            color: const Color(0xFF8A9BB8),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text(
              label != null ? 'Tamam' : 'İptal',
              style: GoogleFonts.rajdhani(color: const Color(0xFF8A9BB8)),
            ),
          ),
          if (label == null && gp.canOfferFacilityNamingSale(branchName))
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dCtx);
                final paid = gp.sellFacilityNamingRights(branchName);
                if (!ctx.mounted) return;
                if (paid != null) {
                  final academy = gp.facilityAcademyLabel(branchName);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Tek seferlik gelir ${_fmtMoney(paid)}. '
                        '${academy ?? ""}',
                      ),
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFBF00),
                foregroundColor: const Color(0xFF0A1628),
              ),
              child: Text(
                'Satışı onayla',
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtMoney(double amount) {
    if (amount >= 1000000) return '€${(amount / 1000000).toStringAsFixed(2)}M';
    if (amount >= 1000) return '€${(amount / 1000).toStringAsFixed(0)}K';
    return '€${amount.toStringAsFixed(0)}';
  }

  void _confirmReset(BuildContext ctx, GameProvider gp) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF111C33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFF5252), size: 22),
            const SizedBox(width: 10),
            Text('Yeni Kulüp Kur',
                style: GoogleFonts.rajdhani(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
        content: Text(
          'Tüm ilerleme ve kayıt kalıcı olarak silinecek.\n\nBu işlem geri alınamaz. Devam etmek istiyor musun?',
          style: GoogleFonts.rajdhani(
              fontSize: 15, color: const Color(0xFF8A9BB8), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('İptal',
                style: GoogleFonts.rajdhani(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8A9BB8))),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: Text('Sil ve Yeni Başla',
                style: GoogleFonts.rajdhani(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await gp.clearSaveAndReset();
              if (!ctx.mounted) return;
              Navigator.of(ctx).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainMenuScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final club = gp.currentClub;

    if (club == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (!_clubBranchesReady(club)) {
      return const Scaffold(
        backgroundColor: Color(0xFF080F1E),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final clubAccent = _hex(club.primaryColor, const Color(0xFF38BDF8));
    final uiAccent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ① Sabit global bar
                _GlobalInfoBar(
                  gp: gp,
                  club: club,
                  clubAccent: clubAccent,
                  uiAccent: uiAccent,
                  branchIcons: _branchIcons,
                  branchAccents: _branchAccents,
                  onReset: () => _confirmReset(context, gp),
                ),
                // ② Hafta ilerleme çubuğu
                _WeekProgressBar(gp: gp, accent: uiAccent),
                if (_autoPlaying)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: AnimatedBuilder(
                      animation: _autoBlinkCtrl,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.autorenew,
                              size: 16,
                              color: uiAccent.withValues(alpha: 0.9)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Otomatik mod · 1 sn aralıklarla · Duraklatmak için Oynat’a tekrar dokun',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.rajdhani(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: uiAccent.withValues(alpha: 0.95),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      builder: (_, blinkChild) {
                        final o = 0.38 + _autoBlinkCtrl.value * 0.62;
                        return Opacity(
                          opacity: o,
                          child: blinkChild,
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                // ③ Kulüp / Fikstür / Arşiv
                Expanded(
                  child: IndexedStack(
                    index: _dashboardMainTab.clamp(0, 2),
                    sizing: StackFit.expand,
                    children: [
                      _BranchCarousel(
                        gp: gp,
                        club: club,
                        pageCtrl: _pageCtrl,
                        currentPage: _currentPage,
                        branches: _branches,
                        branchIcons: _branchIcons,
                        branchAccents: _branchAccents,
                        pageDotColor: uiAccent,
                        onPageChanged: (i) =>
                            setState(() => _currentPage = i),
                        onFacilityNamingSale: (b) =>
                            _promptFacilityNaming(context, gp, b),
                      ),
                      _FixtureTabContent(gp: gp, accent: uiAccent),
                      _MatchHistoryTabContent(gp: gp, accent: uiAccent),
                    ],
                  ),
                ),
                if (_dashboardMainTab == 0) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LayoutBuilder(
                      builder: (ctx, c) {
                        final narrow = c.maxWidth < 360;
                        Widget chip({
                          required VoidCallback onTap,
                          required IconData icon,
                          required String label,
                          required Color accent,
                        }) {
                          return GestureDetector(
                            onTap: onTap,
                            child: Container(
                              height: 52,
                              padding: EdgeInsets.symmetric(
                                  horizontal: narrow ? 8 : 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111C33),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: accent.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon,
                                      color: accent, size: narrow ? 18 : 20),
                                  if (!narrow) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: GoogleFonts.rajdhani(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: accent,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              chip(
                                onTap: () => showInvestmentMenu(context),
                                icon: Icons.construction_rounded,
                                label: 'Geliştir',
                                accent: uiAccent,
                              ),
                              SizedBox(width: narrow ? 6 : 8),
                              chip(
                                onTap: () =>
                                    showLeagueStandingsSheet(context),
                                icon: Icons.table_chart_rounded,
                                label: 'Puan',
                                accent: uiAccent,
                              ),
                              SizedBox(width: narrow ? 6 : 8),
                              chip(
                                onTap: () => showTrophyRoomSheet(context),
                                icon: Icons.museum_rounded,
                                label: 'Müze',
                                accent: uiAccent,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (ctx, c) {
                      final narrow = c.maxWidth < 360;
                      final autoControlsDisabled = gp.isSeasonOver ||
                          gp.needsSponsorSelection ||
                          _isSimulating ||
                          _fastSkipping;
                      final fastFinishDisabled = gp.isSeasonOver ||
                          gp.needsSponsorSelection ||
                          _autoPlaying ||
                          _fastSkipping ||
                          _isSimulating;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Tooltip(
                            message: _autoPlaying
                                ? 'Duraklat'
                                : 'Oynat · her 1 sn hafta',
                            child: IconButton(
                              onPressed: autoControlsDisabled
                                  ? null
                                  : () => _toggleAutoPlay(gp),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF111C33),
                                foregroundColor: uiAccent,
                                disabledBackgroundColor:
                                    const Color(0xFF162236),
                                disabledForegroundColor:
                                    const Color(0xFF546174),
                                padding: const EdgeInsets.all(10),
                              ),
                              icon: Icon(_autoPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                            ),
                          ),
                          Tooltip(
                            message: 'Sezonu hızlı bitir (test / beta)',
                            child: IconButton(
                              onPressed: fastFinishDisabled
                                  ? null
                                  : () => _promptFastFinishSeason(gp),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF111C33),
                                foregroundColor: fastFinishDisabled
                                    ? const Color(0xFF546174)
                                    : const Color(0xFFFFB74D),
                                disabledBackgroundColor:
                                    const Color(0xFF162236),
                                disabledForegroundColor:
                                    const Color(0xFF546174),
                                padding: const EdgeInsets.all(10),
                              ),
                              icon: Icon(
                                Icons.flash_on_rounded,
                                color: fastFinishDisabled
                                    ? const Color(0xFF546174)
                                    : const Color(0xFFFFB74D),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _AdvanceButton(
                              gp: gp,
                              accent: uiAccent,
                              isSimulating: _isSimulating,
                              interactionBlocked:
                                  _autoPlaying || _fastSkipping,
                              horizontalPadding: narrow ? 6 : 10,
                              spinCtrl: _spinCtrl,
                              onTap: () => _onAdvanceWeek(gp),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                NavigationBar(
                  height: 64,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.alwaysShow,
                  indicatorColor: uiAccent.withValues(alpha: 0.18),
                  backgroundColor: const Color(0xFF0C1528),
                  selectedIndex: _dashboardMainTab.clamp(0, 2),
                  onDestinationSelected: (i) =>
                      setState(() => _dashboardMainTab = i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: 'Kulüp',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.sports_soccer_outlined),
                      selectedIcon: Icon(Icons.sports_soccer_rounded),
                      label: 'Maçlar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_toggle_off_rounded),
                      selectedIcon: Icon(Icons.history_rounded),
                      label: 'Tarihçe',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // ⑤ Simülasyon overlay — yalnızca manuel "Haftayı İlerle" animasyonunda
          if (_isSimulating && !_autoPlaying && !_fastSkipping)
            _SimulatingOverlay(spinCtrl: _spinCtrl),
          if (_fastSkipping)
            Positioned(
              left: 14,
              right: 14,
              top: 10,
              child: IgnorePointer(
                child: Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161E30).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFFFB74D).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flash_on_rounded,
                            size: 16, color: uiAccent.withValues(alpha: 0.95)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hızlı simülasyon · tablolar ve kasa güncelleniyor',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.rajdhani(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE8EDF7),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Maçlar (fikstür) ve arşiv sekmeleri
// ---------------------------------------------------------------------------

IconData _branchMatchIcon(String branch) {
  if (branch == CountryData.football) return Icons.sports_soccer_rounded;
  if (branch == CountryData.basketball) return Icons.sports_basketball_rounded;
  if (branch == CountryData.volleyball) return Icons.sports_volleyball_rounded;
  return Icons.sports_rounded;
}

class _FixtureSectionCaption extends StatelessWidget {
  final String title;
  final Color accent;

  const _FixtureSectionCaption({required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.rajdhani(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFCFD8E9),
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingMatchTile extends StatelessWidget {
  final MatchSchedule s;
  final Color accent;

  const _UpcomingMatchTile({required this.s, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111C33),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_branchMatchIcon(s.branch),
                    size: 18, color: accent.withValues(alpha: 0.95)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.branch,
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8A9BB8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'H${s.calendarWeek} · T${s.leagueRoundIndex}',
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${s.homeTeam}  vs  ${s.awayTeam}',
              style: GoogleFonts.rajdhani(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFE8EDF7),
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedMatchTile extends StatelessWidget {
  final MatchResult m;
  final Color accent;

  const _ArchivedMatchTile({required this.m, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111C33),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFF273552).withValues(alpha: 0.95)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_branchMatchIcon(m.branch),
                    size: 18, color: accent.withValues(alpha: 0.95)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m.branch,
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8A9BB8),
                    ),
                  ),
                ),
                Text(
                  'S${m.seasonNumber} · H${m.calendarWeek}',
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7A92),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    m.homeTeam,
                    style: GoogleFonts.rajdhani(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFCFD8E9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    m.scoreLineTotal,
                    style: GoogleFonts.rajdhani(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    m.awayTeam,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.rajdhani(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFCFD8E9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Biz: ${m.goalsFor}-${m.goalsAgainst}',
              style: GoogleFonts.rajdhani(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6B7A92),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixtureTabContent extends StatelessWidget {
  final GameProvider gp;
  final Color accent;

  const _FixtureTabContent({required this.gp, required this.accent});

  @override
  Widget build(BuildContext context) {
    final cw = gp.currentWeek;
    final upcoming = gp.seasonSchedule
        .where((s) => s.involvesPlayerClub && s.calendarWeek >= cw)
        .toList()
      ..sort((a, b) {
        final w = a.calendarWeek.compareTo(b.calendarWeek);
        if (w != 0) return w;
        return a.branch.compareTo(b.branch);
      });

    final seasonPlayed = gp.matchHistory
        .where((m) => m.seasonNumber == gp.seasonNumber)
        .toList()
      ..sort((a, b) {
        final w = b.calendarWeek.compareTo(a.calendarWeek);
        if (w != 0) return w;
        return b.branch.compareTo(a.branch);
      });

    Widget emptyHint(String msg) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            msg,
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF6B7A92),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fikstür',
            style: GoogleFonts.rajdhani(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFE8EDF7),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _FixtureSectionCaption(
                    title: 'Gelecek maçlar', accent: accent),
                if (upcoming.isEmpty)
                  emptyHint('Bu sezon için planlı iç saha/deplasman maçı yok.')
                else
                  ...upcoming
                      .map((s) => _UpcomingMatchTile(s: s, accent: accent)),
                _FixtureSectionCaption(title: 'Bu sezon skorlar', accent: accent),
                if (seasonPlayed.isEmpty)
                  emptyHint('Henüz bu sezon lig maçı kaydı yok.')
                else
                  ...seasonPlayed
                      .map((m) => _ArchivedMatchTile(m: m, accent: accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchHistoryTabContent extends StatelessWidget {
  final GameProvider gp;
  final Color accent;

  const _MatchHistoryTabContent({required this.gp, required this.accent});

  @override
  Widget build(BuildContext context) {
    final xs = [...gp.matchHistory];
    xs.sort((a, b) {
      final sn = b.seasonNumber.compareTo(a.seasonNumber);
      if (sn != 0) return sn;
      final w = b.calendarWeek.compareTo(a.calendarWeek);
      if (w != 0) return w;
      return b.branch.compareTo(a.branch);
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tarihçe',
            style: GoogleFonts.rajdhani(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFE8EDF7),
              letterSpacing: 0.6,
            ),
          ),
          Text(
            xs.isEmpty ? 'Arşivde maç yok.' : '${xs.length} kayıt',
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7A92),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: xs.isEmpty
                ? Center(
                    child: Text(
                      'Sezonları ilerledikçe skor kartları burada birikecek.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF6B7A92),
                      ),
                    ),
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      for (final m in xs)
                        _ArchivedMatchTile(m: m, accent: accent),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ① Global Info Bar — sabit, kaydırma etkilemez
// ---------------------------------------------------------------------------
class _GlobalInfoBar extends StatefulWidget {
  final GameProvider gp;
  final dynamic club;
  /// Kulüp renkleri: yalnızca badge çerçevesi ve in çizgi.
  final Color clubAccent;
  /// Uygulama vurgusu (butonlar, kasa metni).
  final Color uiAccent;
  final Map<String, IconData> branchIcons;
  final Map<String, Color> branchAccents;
  final VoidCallback onReset;

  const _GlobalInfoBar({
    required this.gp,
    required this.club,
    required this.clubAccent,
    required this.uiAccent,
    required this.branchIcons,
    required this.branchAccents,
    required this.onReset,
  });

  @override
  State<_GlobalInfoBar> createState() => _GlobalInfoBarState();
}

class _GlobalInfoBarState extends State<_GlobalInfoBar> {
  final _overlayKey = GlobalKey<_FloatingDeltaOverlayState>();
  double? _prevTreasury;

  @override
  void didUpdateWidget(_GlobalInfoBar old) {
    super.didUpdateWidget(old);
    final newT = widget.club?.treasury as double?;
    if (newT != null && _prevTreasury != null && newT != _prevTreasury) {
      _overlayKey.currentState?.spawn(newT - _prevTreasury!);
    }
    _prevTreasury = newT;
  }

  @override
  void initState() {
    super.initState();
    _prevTreasury = widget.club?.treasury as double?;
  }

  @override
  Widget build(BuildContext context) {
    final gp       = widget.gp;
    final club     = widget.club;
    final ca       = widget.clubAccent;
    final ui       = widget.uiAccent;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1626),
        border: Border(
          bottom: BorderSide(
            color: ca.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İnce kulüp rengi çizgisi
          Container(
            height: 2,
            width: 72,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ca,
                  ca.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              _ClubBadge(accent: ca),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: GoogleFonts.rajdhani(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${club.city}  ·  Başkan ${gp.currentPresident?.name ?? ''}',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        color: const Color(0xFF8A9BB8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Tooltip(
                      message:
                          'Bilet/yayın ek geliri (itibar): '
                          '%${(club.reputation * 0.1).toStringAsFixed(1)} '
                          '(temel gelire en fazla %10 kadar)',
                      preferBelow: true,
                      verticalOffset: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'İtibar ${club.reputation}',
                            style: GoogleFonts.rajdhani(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE2E8F0),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(Icons.star_outline_rounded,
                              color: ui.withValues(alpha: 0.9), size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _FloatingDeltaOverlay(
                key: _overlayKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedCounter(
                      value: (club.treasury as double?) ?? 0,
                      formatter: _fmt,
                      style: GoogleFonts.rajdhani(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ui,
                      ),
                    ),
                    if (gp.lastEconomySummary != null) ...[
                      _NetChangeBadge(net: gp.lastEconomySummary!.netChange),
                      if (gp.lastEconomySummary!.sponsorWinBonus > 0)
                        _SponsorBonusChip(
                            bonus: gp.lastEconomySummary!.sponsorWinBonus),
                    ] else
                      Text(
                        'Kasa',
                        style: GoogleFonts.rajdhani(
                            fontSize: 11,
                            color: const Color(0xFF8A9BB8)),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Oyunu kaydet',
                icon: const Icon(Icons.save_outlined,
                    color: Color(0xFF94A3B8), size: 20),
                onPressed: () async {
                  await gp.saveGame();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Oyun kaydedildi.',
                        style: GoogleFonts.rajdhani(),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Ana menü',
                icon: const Icon(Icons.logout_rounded,
                    color: Color(0xFF8A9BB8), size: 20),
                onPressed: widget.onReset,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Branş mini-özet satırı
          Row(
            children: [
              CountryData.football,
              CountryData.basketball,
              CountryData.volleyball,
            ]
                .map((b) => Expanded(
                      child: _BranchMiniChip(
                        branch: b,
                        gp: gp,
                        icon:
                            widget.branchIcons[b] ?? Icons.sports_rounded,
                        accent: widget.branchAccents[b] ??
                            const Color(0xFF38BDF8),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ClubBadge extends StatelessWidget {
  final Color accent;
  const _ClubBadge({required this.accent});

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF151E30),
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.85), width: 2),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 14,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.shield_rounded,
            color: Color(0xFFE2E8F0), size: 21),
      );
}

class _BranchMiniChip extends StatelessWidget {
  final String branch;
  final GameProvider gp;
  final IconData icon;
  final Color accent;

  const _BranchMiniChip({
    required this.branch,
    required this.gp,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final pts = gp.branchPoints(branch);
    final league = gp.branchLeagueName(branch);

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 13),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  branch,
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AnimatedCounter(
            value: pts.toDouble(),
            formatter: (v) => '${v.round()} puan',
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            league,
            style: GoogleFonts.rajdhani(
              fontSize: 10,
              color: const Color(0xFF8A9BB8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ② Hafta ilerleme çubuğu
// ---------------------------------------------------------------------------
class _WeekProgressBar extends StatelessWidget {
  final GameProvider gp;
  final Color accent;
  const _WeekProgressBar({required this.gp, required this.accent});

  @override
  Widget build(BuildContext context) {
    final progress =
        ((gp.currentWeek - 1) / gp.seasonLength).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${gp.calendarYear} · Sezon ${gp.seasonNumber}',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      gp.isSeasonOver
                          ? '✓ Sezon tamamlandı · ${gp.seasonLength} hafta'
                          : 'Hafta ${gp.currentWeek} / ${gp.seasonLength}',
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: gp.isSeasonOver
                            ? const Color(0xFF69F0AE)
                            : const Color(0xFFCED6E5),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '%${(progress * 100).round()}',
                style: GoogleFonts.rajdhani(
                    fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFF253047),
              valueColor: AlwaysStoppedAnimation<Color>(
                gp.isSeasonOver ? const Color(0xFF69F0AE) : accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ③ Branş Carousel
// ---------------------------------------------------------------------------
class _BranchCarousel extends StatelessWidget {
  final GameProvider gp;
  final Club club;
  final PageController pageCtrl;
  final int currentPage;
  final List<String> branches;
  final Map<String, IconData> branchIcons;
  final Map<String, Color> branchAccents;
  final Color pageDotColor;
  final ValueChanged<int> onPageChanged;
  final void Function(String branch) onFacilityNamingSale;

  const _BranchCarousel({
    required this.gp,
    required this.club,
    required this.pageCtrl,
    required this.currentPage,
    required this.branches,
    required this.branchIcons,
    required this.branchAccents,
    required this.pageDotColor,
    required this.onPageChanged,
    required this.onFacilityNamingSale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: pageCtrl,
            itemCount: branches.length,
            onPageChanged: onPageChanged,
            itemBuilder: (ctx, i) {
              final name = branches[i];
              Branch? branchModel;
              for (final b in club.branches) {
                if (b.name == name) {
                  branchModel = b;
                  break;
                }
              }
              if (branchModel == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _BranchCard(
                gp: gp,
                branchName: name,
                branch: branchModel,
                accent: branchAccents[name] ??
                    const Color(0xFF38BDF8),
                icon: branchIcons[name] ?? Icons.sports_rounded,
                isActive: i == currentPage,
                onFacilityNamingSale: onFacilityNamingSale,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            branches.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == currentPage ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == currentPage
                    ? pageDotColor
                    : const Color(0xFF2C3546),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BranchCard extends StatelessWidget {
  final GameProvider gp;
  final String branchName;
  final Branch branch;
  final Color accent;
  final IconData icon;
  final bool isActive;
  final void Function(String branch) onFacilityNamingSale;

  const _BranchCard({
    required this.gp,
    required this.branchName,
    required this.branch,
    required this.accent,
    required this.icon,
    required this.isActive,
    required this.onFacilityNamingSale,
  });

  @override
  Widget build(BuildContext context) {
    final successRate = branch.successRate;
    final budget = branch.budget;
    final pts = gp.branchPoints(branchName);
    final league = gp.branchLeagueName(branchName);
    final levelIdx = gp.branchLeagueIndex(branchName);
    final totalLevels = BranchLeagueData.leagueCount(branchName);
    final difficulty = BranchLeagueData.difficultyAt(branchName, levelIdx);
    final impactMultiplier =
        BranchLeagueData.budgetImpactMultipliers[branchName] ?? 1.0;
    final budgetEfficiency =
        budget > 0 ? (budget * impactMultiplier / difficulty) : 0.0;

    final isCupWeek   = gp.isCurrentWeekCupWeek;
    final isInCup     = gp.isBranchInCup(branchName);
    final cupRound    = gp.branchCupRound(branchName);
    final showCupBadge = isCupWeek && isInCup;

    return AnimatedScale(
      scale: isActive ? 1.0 : 0.93,
      duration: const Duration(milliseconds: 250),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF111C33),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive
                ? accent.withValues(alpha: 0.5)
                : const Color(0xFF1E2D48),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branchName,
                        style: GoogleFonts.rajdhani(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        league,
                        style: GoogleFonts.rajdhani(
                          fontSize: 13,
                          color: accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rozet grubu: lig seviye + kupa maçı uyarısı
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Seviye ${levelIdx + 1}/$totalLevels',
                        style: GoogleFonts.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                    if (showCupBadge) ...[
                      const SizedBox(height: 4),
                      _CupMatchBadge(
                          roundLabel: cupRound?.label ?? ''),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Sponsor bandı
            _SponsorBadge(gp: gp, branch: branchName, accent: accent),
            const SizedBox(height: 10),
            _FacilityTierStrip(level: gp.facilityLevel(branchName), accent: accent),
            if (gp.facilityAcademyLabel(branchName) != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.badge_rounded, size: 15, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tesis: ${gp.facilityAcademyLabel(branchName)!}',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (gp.canOfferFacilityNamingSale(branchName))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onFacilityNamingSale(branchName),
                  icon: Icon(Icons.handshake_rounded, size: 18, color: accent),
                  label: Text(
                    'Tesis adı sat (Arena)',
                    style:
                        GoogleFonts.rajdhani(fontWeight: FontWeight.w700, color: accent),
                  ),
                ),
              ),
            const SizedBox(height: 14),

            // Başarı Oranı — progress bar
            _statRow('Başarı Oranı',
                '%${(successRate * 100).round()}', accent),
            const SizedBox(height: 6),
            _progressBar(successRate, accent),
            const SizedBox(height: 16),

            // Bütçe Verimliliği — progress bar
            _statRow(
              'Bütçe Verimliliği',
              '${(budgetEfficiency * 100).toStringAsFixed(1)}%',
              const Color(0xFF8A9BB8),
            ),
            const SizedBox(height: 6),
            _progressBar(budgetEfficiency.clamp(0.0, 1.0),
                const Color(0xFF8A9BB8)),
            const SizedBox(height: 16),

            // Bütçe
            _statRow(
                'Branş Bütçesi', _fmt(budget), const Color(0xFF8A9BB8)),

            // Kupa durumu
            const SizedBox(height: 10),
            _CupStatusRow(
              branchName: branchName,
              cupRound: cupRound,
              showCupBadge: showCupBadge,
              accent: accent,
            ),
            const Spacer(),

            // Sezon puanı kartı
            _PointsCard(pts: pts, accent: accent),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.rajdhani(
                  fontSize: 13, color: const Color(0xFF8A9BB8))),
          Text(value,
              style: GoogleFonts.rajdhani(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              )),
        ],
      );

  Widget _progressBar(double value, Color color) => ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 8,
          backgroundColor: const Color(0xFF1E2D48),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
}

class _FacilityTierStrip extends StatelessWidget {
  final int level;
  final Color accent;

  const _FacilityTierStrip({required this.level, required this.accent});

  static IconData _iconForStep(int step) {
    return switch (step) {
      1 => Icons.warehouse_rounded,
      2 => Icons.home_work_rounded,
      3 => Icons.business_rounded,
      4 => Icons.corporate_fare_rounded,
      5 => Icons.apartment_rounded,
      _ => Icons.construction_rounded,
    };
  }

  static String _labelForCurrent(int lvl) {
    if (lvl <= 0) return 'Tesis yatırımı yapılmadı';
    if (lvl <= 1) return 'Konteyner / eski bina';
    if (lvl == 2) return 'Mahalle ölçeği tesis';
    if (lvl == 3) return 'Şehir ölçeği kompleks';
    if (lvl == 4) return 'Profesyonel kampüs';
    return 'Modern plaza / kampüs';
  }

  @override
  Widget build(BuildContext context) {
    final capped = level.clamp(0, InvestmentCatalog.maxLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tesis gelişimi',
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF8A9BB8),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(InvestmentCatalog.maxLevel, (i) {
            final step = i + 1;
            final on = capped >= step;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 4 ? 4 : 0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: on
                            ? accent.withValues(alpha: 0.18)
                            : const Color(0xFF1E2D48),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: on
                              ? accent.withValues(alpha: 0.45)
                              : const Color(0xFF2C3546),
                        ),
                      ),
                      child: Icon(
                        _iconForStep(step),
                        size: 18,
                        color: on ? accent : const Color(0xFF4A5568),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$step',
                      style: GoogleFonts.rajdhani(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: on ? accent : const Color(0xFF5C6B88),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          _labelForCurrent(capped),
          style: GoogleFonts.rajdhani(
            fontSize: 12,
            color: const Color(0xFFCFD8E9),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _PointsCard extends StatelessWidget {
  final int pts;
  final Color accent;

  const _PointsCard({
    required this.pts,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sezon Puanı',
              style: GoogleFonts.rajdhani(
                  fontSize: 13, color: const Color(0xFF8A9BB8))),
          const SizedBox(height: 8),
          AnimatedCounter(
            value: pts.toDouble(),
            formatter: (v) => '${v.round()}',
            style: GoogleFonts.rajdhani(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: accent,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sponsor bandı
// ---------------------------------------------------------------------------
class _SponsorBadge extends StatelessWidget {
  final GameProvider gp;
  final String branch;
  final Color accent;

  const _SponsorBadge({
      required this.gp, required this.branch, required this.accent});

  static const _typeColors = {
    SponsorType.guaranteed:  Color(0xFF69F0AE),
    SponsorType.performance: Color(0xFF4FC3F7),
    SponsorType.prestige:    Color(0xFFFFBF00),
  };
  static const _typeIcons = {
    SponsorType.guaranteed:  Icons.verified_rounded,
    SponsorType.performance: Icons.trending_up_rounded,
    SponsorType.prestige:    Icons.star_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final active = gp.activeSponsor(branch);

    if (active == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2D48),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.handshake_outlined,
                color: Color(0xFF8A9BB8), size: 14),
            const SizedBox(width: 6),
            Text(
              'Sponsor seçilmedi',
              style: GoogleFonts.rajdhani(
                  fontSize: 12, color: const Color(0xFF8A9BB8)),
            ),
          ],
        ),
      );
    }

    final color = _typeColors[active.offer.type]!;
    final icon  = _typeIcons[active.offer.type]!;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              active.offer.sponsorName,
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '€${(active.offer.winBonus / 1000).toStringAsFixed(0)}K/galibiyet',
            style: GoogleFonts.rajdhani(
                fontSize: 11, color: const Color(0xFF8A9BB8)),
          ),
          const SizedBox(width: 8),
          Text(
            '${active.seasonWins} galibiyet',
            style: GoogleFonts.rajdhani(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kupa durumu satırı + "Kupa Maçı" badge
// ---------------------------------------------------------------------------
class _CupStatusRow extends StatelessWidget {
  final String branchName;
  final CupRound? cupRound;
  final bool showCupBadge;
  final Color accent;

  const _CupStatusRow({
    required this.branchName,
    required this.cupRound,
    required this.showCupBadge,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (cupRound == null) {
      return Row(
        children: [
          const Icon(Icons.sports_soccer_outlined,
              color: Color(0xFF8A9BB8), size: 13),
          const SizedBox(width: 5),
          Text('Kupadan Elindi',
              style: GoogleFonts.rajdhani(
                  fontSize: 12, color: const Color(0xFF8A9BB8))),
        ],
      );
    }
    if (cupRound == CupRound.champion) {
      return Row(
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: Color(0xFFFFBF00), size: 14),
          const SizedBox(width: 5),
          Text('🏆 Kupa Şampiyonu!',
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFFBF00),
              )),
        ],
      );
    }
    return Row(
      children: [
        Icon(Icons.emoji_events_outlined, color: accent, size: 13),
        const SizedBox(width: 5),
        Text(
          'Kupada: ${cupRound!.label}',
          style: GoogleFonts.rajdhani(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _CupMatchBadge extends StatelessWidget {
  final String roundLabel;
  const _CupMatchBadge({required this.roundLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
            color: const Color(0xFFFF9800).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: Color(0xFFFF9800), size: 10),
          const SizedBox(width: 3),
          Text(
            'KUPA · $roundLabel',
            style: GoogleFonts.rajdhani(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFF9800),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ④ Haftayı İlerle butonu
// ---------------------------------------------------------------------------
class _AdvanceButton extends StatelessWidget {
  final GameProvider gp;
  final Color accent;
  final bool isSimulating;
  /// Otomatik / hızlı simülasyon sırasında manuel ilerlemeyi kapatır.
  final bool interactionBlocked;
  final AnimationController spinCtrl;
  final VoidCallback onTap;
  final double horizontalPadding;

  const _AdvanceButton({
    required this.gp,
    required this.accent,
    required this.isSimulating,
    this.interactionBlocked = false,
    this.horizontalPadding = 20,
    required this.spinCtrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOver = gp.isSeasonOver;

    final disabledTap = isOver || isSimulating || interactionBlocked;

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: disabledTap ? null : onTap,
          icon: isSimulating
              ? RotationTransition(
                  turns: spinCtrl,
                  child: const Icon(Icons.autorenew_rounded, size: 22),
                )
              : Icon(
                  isOver
                      ? Icons.check_circle_rounded
                      : Icons.skip_next_rounded,
                  size: 22,
                ),
          label: Text(
            isSimulating
                ? 'Sonuçlar Hesaplanıyor...'
                : interactionBlocked && !isOver
                    ? 'Manuel bekleniyor...'
                    : isOver
                        ? 'Sezon Bitti'
                        : 'Haftayı İlerle  ·  ${gp.currentWeek}. Hafta',
            style: GoogleFonts.rajdhani(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: disabledTap
                ? const Color(0xFF1E2D48)
                : accent,
            foregroundColor: disabledTap
                ? const Color(0xFF8A9BB8)
                : const Color(0xFF080F1E),
            disabledBackgroundColor: const Color(0xFF1E2D48),
            disabledForegroundColor: const Color(0xFF8A9BB8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: disabledTap ? 0 : 6,
            shadowColor:
                accent.withValues(alpha: disabledTap ? 0.0 : 0.35),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ⑤ Simülasyon overlay
// ---------------------------------------------------------------------------
class _SimulatingOverlay extends StatelessWidget {
  final AnimationController spinCtrl;
  const _SimulatingOverlay({required this.spinCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF111C33),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2C3546)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: spinCtrl,
                child: const Icon(
                  Icons.sports_score_rounded,
                  color: Color(0xFFFFBF00),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sonuçlar Hesaplanıyor...',
                style: GoogleFonts.rajdhani(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Maçlar simüle ediliyor',
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  color: const Color(0xFF8A9BB8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Haftalık Rapor Bottom Sheet
// ---------------------------------------------------------------------------
class _WeeklyReportSheet extends StatefulWidget {
  final List<WeeklyMatchResult> results;
  final List<CupMatchResult> cupResults;
  final WeeklyEconomySummary? summary;
  final int week;
  final Color primary;
  final Map<String, IconData> branchIcons;
  final Map<String, Color> branchAccents;

  const _WeeklyReportSheet({
    required this.results,
    required this.cupResults,
    this.summary,
    required this.week,
    required this.primary,
    required this.branchIcons,
    required this.branchAccents,
  });

  @override
  State<_WeeklyReportSheet> createState() => _WeeklyReportSheetState();
}

class _WeeklyReportSheetState extends State<_WeeklyReportSheet> {
  // Kaç tane maç/kupa/gelir satırı görünür oldu
  int _visibleMatches   = 0;
  int _visibleCup       = 0;
  bool _showIncome      = false;
  bool _revealComplete  = false;

  @override
  void initState() {
    super.initState();
    _startReveal();
  }

  Future<void> _startReveal() async {
    // Maçlar birer birer açılır (1 saniye arayla)
    for (var i = 0; i < widget.results.length; i++) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _visibleMatches = i + 1);
    }

    // Kupa sonuçları (kısa ara)
    if (widget.cupResults.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 700));
      for (var i = 0; i < widget.cupResults.length; i++) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() => _visibleCup = i + 1);
      }
    }

    // Gelir dökümü son açılır
    if (widget.summary != null && widget.summary!.breakdown.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _showIncome = true);
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _revealComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111C33),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            // Handle
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3546),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Text(
              '${widget.week}. Hafta Raporu',
              style: GoogleFonts.rajdhani(
                fontSize: 20, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 18),

            // ── Maç sonuçları (kademeli açılır) ───────────────────────────
            _sectionHeader('MAÇ SONUÇLARI', Icons.sports_score_rounded,
                widget.primary),
            const SizedBox(height: 8),
            for (var i = 0; i < widget.results.length; i++)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: i < _visibleMatches ? 1.0 : 0.0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 400),
                  offset: i < _visibleMatches
                      ? Offset.zero
                      : const Offset(0, 0.15),
                  curve: Curves.easeOut,
                  child: _MatchRow(
                    result: widget.results[i],
                    icon: widget.branchIcons[widget.results[i].branch] ??
                        Icons.sports,
                    accent: widget.branchAccents[widget.results[i].branch] ??
                        widget.primary,
                  ),
                ),
              ),

            // ── Kupa maçları (kademeli açılır) ────────────────────────────
            if (widget.cupResults.isNotEmpty) ...[
              AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: _visibleCup > 0 ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: _sectionHeader('TÜRKİYE KUPASI',
                      Icons.emoji_events_rounded, const Color(0xFFFF9800)),
                ),
              ),
              for (var i = 0; i < widget.cupResults.length; i++)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: i < _visibleCup ? 1.0 : 0.0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 400),
                    offset: i < _visibleCup
                        ? Offset.zero
                        : const Offset(0, 0.15),
                    curve: Curves.easeOut,
                    child: _CupMatchRow(
                      result: widget.cupResults[i],
                      icon: widget.branchIcons[widget.cupResults[i].branch] ??
                          Icons.sports,
                      accent:
                          widget.branchAccents[widget.cupResults[i].branch] ??
                              widget.primary,
                    ),
                  ),
                ),
            ],

            // ── Gelir dökümü (tüm branşlar açılınca görünür) ──────────────
            if (widget.summary != null &&
                widget.summary!.breakdown.isNotEmpty)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _showIncome ? 1.0 : 0.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _sectionHeader(
                        'GELİR DÖKÜMÜ',
                        Icons.account_balance_wallet_rounded,
                        const Color(0xFF69F0AE)),
                    const SizedBox(height: 10),
                    ...widget.summary!.breakdown.map(
                      (b) => _BranchIncomeRow(
                        income: b,
                        icon: widget.branchIcons[b.branch] ?? Icons.sports,
                        accent: widget.branchAccents[b.branch] ?? widget.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _TotalNetRow(summary: widget.summary!, primary: widget.primary),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            // "Devam Et" butonu sadece tüm reveal bitince aktif
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _revealComplete ? 1.0 : 0.35,
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _revealComplete
                      ? () => Navigator.pop(context)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: widget.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    _revealComplete ? 'Devam Et' : 'Hesaplanıyor…',
                    style: GoogleFonts.rajdhani(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon, Color color) => Row(
    children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Text(label,
          style: GoogleFonts.rajdhani(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 1.5)),
    ],
  );
}

class _MatchRow extends StatelessWidget {
  final WeeklyMatchResult result;
  final IconData icon;
  final Color accent;

  const _MatchRow({
    required this.result,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.hadLeagueMatch) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2744),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3D4F6F)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent.withValues(alpha: 0.5), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.branch,
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              'Bu hafta lig maçı yok',
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8A9BB8),
              ),
            ),
          ],
        ),
      );
    }

    final (outcomeColor, outcomeIcon) = switch (result.outcome) {
      MatchOutcome.win => (const Color(0xFF69F0AE), Icons.arrow_upward_rounded),
      MatchOutcome.draw => (const Color(0xFFFFBF00), Icons.remove_rounded),
      MatchOutcome.loss => (
          const Color(0xFFFF5252),
          Icons.arrow_downward_rounded
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2744),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: outcomeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.branch,
              style: GoogleFonts.rajdhani(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          Icon(outcomeIcon, color: outcomeColor, size: 18),
          const SizedBox(width: 6),
          Text(
            result.outcomeLabel,
            style: GoogleFonts.rajdhani(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: outcomeColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            result.scoreLine,
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8A9BB8),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: outcomeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '+${result.points}',
                style: GoogleFonts.rajdhani(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: outcomeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Branş gelir döküm satırı (haftalık rapor için)
// ---------------------------------------------------------------------------
class _BranchIncomeRow extends StatelessWidget {
  final BranchWeeklyIncome income;
  final IconData icon;
  final Color accent;

  const _BranchIncomeRow({
    required this.income,
    required this.icon,
    required this.accent,
  });

  static String _fmt(double v) {
    if (v.abs() >= 1000000) {
      return '€${(v / 1000000).toStringAsFixed(1)}M';
    }
    if (v.abs() >= 1000) return '€${(v / 1000).toStringAsFixed(0)}K';
    return '€${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    const greenColor = Color(0xFF69F0AE);
    const redColor   = Color(0xFFFF5252);

    final items = <(String, double, IconData)>[
      ('Bilet',    income.ticketRevenue,       Icons.confirmation_num_outlined),
      ('Yayın',    income.broadcastingRevenue, Icons.live_tv_rounded),
      ('Maç Primi',income.matchPrize,          Icons.emoji_events_outlined),
      if (income.sponsorBonus > 0)
        ('Sponsor', income.sponsorBonus,       Icons.handshake_outlined),
      if (income.cupPrize > 0)
        ('Kupa',   income.cupPrize,            Icons.emoji_events_rounded),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branş başlığı + net
          Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(income.branch,
                  style: GoogleFonts.rajdhani(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const Spacer(),
              Text(
                'Net: ${income.net >= 0 ? "+" : ""}${_fmt(income.net)}',
                style: GoogleFonts.rajdhani(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: income.net >= 0 ? greenColor : redColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Kalem kalem gelirler
          Wrap(
            spacing: 6, runSpacing: 5,
            children: items.map((item) {
              final (label, value, iIcon) = item;
              if (value <= 0) return const SizedBox.shrink();
              return _IncomeChip(
                  label: label, value: value, icon: iIcon, color: greenColor);
            }).toList(),
          ),
          // Bakım gideri
          if (income.maintenanceCost > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.build_circle_outlined,
                    color: redColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Bakım: −${_fmt(income.maintenanceCost)}',
                  style: GoogleFonts.rajdhani(
                      fontSize: 11, color: redColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IncomeChip extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _IncomeChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    String fmt(double v) =>
        v >= 1000000 ? '€${(v / 1000000).toStringAsFixed(1)}M'
        : v >= 1000  ? '€${(v / 1000).toStringAsFixed(0)}K'
                     : '€${v.toStringAsFixed(0)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 3),
          Text('$label +${fmt(value)}',
              style: GoogleFonts.rajdhani(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _TotalNetRow extends StatelessWidget {
  final WeeklyEconomySummary summary;
  final Color primary;
  const _TotalNetRow({required this.summary, required this.primary});

  @override
  Widget build(BuildContext context) {
    String fmt(double v) {
      final sign = v >= 0 ? '+' : '';
      if (v.abs() >= 1000000) {
        return '$sign€${(v / 1000000).toStringAsFixed(2)}M';
      }
      if (v.abs() >= 1000) return '$sign€${(v / 1000).toStringAsFixed(1)}K';
      return '$sign€${v.toStringAsFixed(0)}';
    }

    final positive = summary.netChange >= 0;
    final color = positive ? const Color(0xFF69F0AE) : const Color(0xFFFF5252);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Haftalık Net Değişim',
                    style: GoogleFonts.rajdhani(
                        fontSize: 12, color: const Color(0xFF8A9BB8))),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 10,
                  children: [
                    if (summary.broadcastingTotal > 0)
                      _SmallStat('Yayın',
                          '€${(summary.broadcastingTotal / 1000).toStringAsFixed(0)}K',
                          const Color(0xFF4FC3F7)),
                    if (summary.matchPrizeTotal > 0)
                      _SmallStat('Maç Primi',
                          '€${(summary.matchPrizeTotal / 1000).toStringAsFixed(0)}K',
                          const Color(0xFF69F0AE)),
                    if (summary.cupPrizeTotal > 0)
                      _SmallStat('Kupa',
                          '€${(summary.cupPrizeTotal / 1000).toStringAsFixed(0)}K',
                          const Color(0xFFFF9800)),
                    if (summary.sponsorWinBonus > 0)
                      _SmallStat('Sponsor',
                          '€${(summary.sponsorWinBonus / 1000).toStringAsFixed(0)}K',
                          const Color(0xFFCE93D8)),
                    _SmallStat('Bakım',
                        '−€${(summary.totalCosts / 1000).toStringAsFixed(0)}K',
                        const Color(0xFFFF5252)),
                  ],
                ),
              ],
            ),
          ),
          Text(
            fmt(summary.netChange),
            style: GoogleFonts.rajdhani(
              fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SmallStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Text(
        '$label: $value',
        style: GoogleFonts.rajdhani(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      );
}

// ---------------------------------------------------------------------------
// Kupa maç satırı (haftalık rapor için)
// ---------------------------------------------------------------------------
class _CupMatchRow extends StatelessWidget {
  final CupMatchResult result;
  final IconData icon;
  final Color accent;

  const _CupMatchRow({
    required this.result,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    const cupColor   = Color(0xFFFF9800);
    final winColor   = const Color(0xFF69F0AE);
    final loseColor  = const Color(0xFFFF5252);
    final resultColor = result.advanced ? winColor : loseColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cupColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cupColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: cupColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.branch} · ${result.round.label}',
                  style: GoogleFonts.rajdhani(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Rakip: ${result.opponentLeague}',
                      style: GoogleFonts.rajdhani(
                          fontSize: 11, color: const Color(0xFF8A9BB8)),
                    ),
                    if (result.opponentWasHigherLeague) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: loseColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Üst Lig',
                            style: GoogleFonts.rajdhani(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: loseColor)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                result.advanced ? 'TUR ATLANDI' : 'ELENDİ',
                style: GoogleFonts.rajdhani(
                  fontSize: 12, fontWeight: FontWeight.w800,
                  color: resultColor,
                ),
              ),
              if (result.prizeEarned > 0)
                Text(
                  '+€${(result.prizeEarned / 1000).toStringAsFixed(0)}K',
                  style: GoogleFonts.rajdhani(
                      fontSize: 11, color: winColor,
                      fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedCounter — sayı değişimlerini 500ms'de tık tık animasyonla gösterir
// ---------------------------------------------------------------------------
class AnimatedCounter extends StatefulWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _displayedFrom = 0;

  @override
  void initState() {
    super.initState();
    _displayedFrom = widget.value;
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: widget.value, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      // Animasyon ortasındaysa mevcut görünen değerden başla
      final currentVal = _anim.value;
      _displayedFrom = currentVal;
      _anim = Tween<double>(begin: _displayedFrom, end: widget.value)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (context2, child2) =>
            Text(widget.formatter(_anim.value), style: widget.style),
      );
}

// ---------------------------------------------------------------------------
// FloatingDeltaOverlay — Stack ile kasanın yanında uçan +/- para metni
// ---------------------------------------------------------------------------

/// Tek bir uçan delta kaydı.
class _DeltaEntry {
  final double amount;
  final UniqueKey key;
  _DeltaEntry(this.amount) : key = UniqueKey();
}

/// Stack'in içinde tek bir uçan metin (yukarı kayar + solar).
class _FloatingDeltaText extends StatefulWidget {
  final double amount;
  final VoidCallback onDone;

  const _FloatingDeltaText({
    super.key,
    required this.amount,
    required this.onDone,
  });

  @override
  State<_FloatingDeltaText> createState() => _FloatingDeltaTextState();
}

class _FloatingDeltaTextState extends State<_FloatingDeltaText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _offsetY;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _offsetY = Tween<double>(begin: 0, end: -52)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.0), weight: 45),
    ]).animate(_ctrl);
    _ctrl.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final positive = widget.amount >= 0;
    final color = positive ? const Color(0xFF69F0AE) : const Color(0xFFFF5252);
    final sign  = positive ? '+' : '';
    final abs   = widget.amount.abs();
    final label = abs >= 1000000
        ? '$sign€${(widget.amount / 1000000).toStringAsFixed(2)}M'
        : abs >= 1000
            ? '$sign€${(widget.amount / 1000).toStringAsFixed(1)}K'
            : '$sign€${widget.amount.toStringAsFixed(0)}';

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context2, child2) => Transform.translate(
        offset: Offset(0, _offsetY.value),
        child: Opacity(
          opacity: _opacity.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              label,
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper: çocuğunu Stack içine alır, uçan deltaları onun üstüne katlar.
class _FloatingDeltaOverlay extends StatefulWidget {
  final Widget child;

  const _FloatingDeltaOverlay({super.key, required this.child});

  @override
  State<_FloatingDeltaOverlay> createState() => _FloatingDeltaOverlayState();
}

class _FloatingDeltaOverlayState extends State<_FloatingDeltaOverlay> {
  final List<_DeltaEntry> _entries = [];

  void spawn(double amount) {
    if (!mounted) return;
    setState(() => _entries.add(_DeltaEntry(amount)));
  }

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          for (final e in _entries)
            Positioned(
              right: 0,
              bottom: 0,
              child: _FloatingDeltaText(
                key: e.key,
                amount: e.amount,
                onDone: () {
                  if (mounted) setState(() => _entries.remove(e));
                },
              ),
            ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Net Değişim Rozeti — kasanın altında geçen haftanın kar/zararı
// ---------------------------------------------------------------------------
class _NetChangeBadge extends StatelessWidget {
  final double net;
  const _NetChangeBadge({required this.net});

  @override
  Widget build(BuildContext context) {
    final positive = net >= 0;
    final color =
        positive ? const Color(0xFF69F0AE) : const Color(0xFFFF5252);
    final sign = positive ? '+' : '';
    final label = net.abs() >= 1000
        ? '$sign€${(net / 1000).toStringAsFixed(1)}K'
        : '$sign€${net.toStringAsFixed(0)}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          positive ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
          color: color,
          size: 14,
        ),
        Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sponsorluk Primi chip — o hafta kazanılan sponsor win bonusu
// ---------------------------------------------------------------------------
class _SponsorBonusChip extends StatelessWidget {
  final double bonus;
  const _SponsorBonusChip({required this.bonus});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE040FB);
    final label = bonus >= 1000
        ? '+€${(bonus / 1000).toStringAsFixed(0)}K'
        : '+€${bonus.toStringAsFixed(0)}';

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.handshake_rounded, color: color, size: 10),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Yardımcı
// ---------------------------------------------------------------------------
String _fmt(double amount) {
  if (amount.abs() >= 1000000) {
    return '€${(amount / 1000000).toStringAsFixed(2)}M';
  }
  if (amount.abs() >= 1000) {
    return '€${(amount / 1000).toStringAsFixed(0)}K';
  }
  return '€${amount.toStringAsFixed(0)}';
}
