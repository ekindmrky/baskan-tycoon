import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:presidento/logic/game_provider.dart';

Color _hex(String hex, Color fallback) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return fallback;
  }
}

class SponsorSelectionScreen extends StatefulWidget {
  const SponsorSelectionScreen({super.key});

  @override
  State<SponsorSelectionScreen> createState() => _SponsorSelectionScreenState();
}

class _SponsorSelectionScreenState extends State<SponsorSelectionScreen> {
  int _currentBranchPage = 0;
  final PageController _pageCtrl = PageController();

  /// Ardışık «Sezona Başla» tıklamalarını ve navigasyon yarışını önler.
  bool _isStartingSeason = false;

  static const _branches = [
    CountryData.football,
    CountryData.basketball,
    CountryData.volleyball,
  ];
  static const _branchIcons = {
    CountryData.football:   Icons.sports_soccer_rounded,
    CountryData.basketball: Icons.sports_basketball_rounded,
    CountryData.volleyball: Icons.sports_volleyball_rounded,
  };

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _onStartSeason(BuildContext ctx, GameProvider gp) async {
    if (_isStartingSeason || !gp.allSponsorsSelected) return;

    setState(() => _isStartingSeason = true);
    try {
      gp.completeSponsorSelection();
      await gp.saveGame();
      if (!ctx.mounted) return;
      Navigator.of(ctx).pop();
    } catch (e, st) {
      debugPrint('Sezona başlarken kayıt hatası: $e\n$st');
      if (!mounted) return;
      setState(() => _isStartingSeason = false);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            'Kayıt sırasında sorun oluştu. Tekrar deneyin.',
            style: GoogleFonts.rajdhani(),
          ),
        ),
      );
    }
  }

  void _selectSponsor(GameProvider gp, String branch, SponsorOffer offer) {
    gp.selectSponsor(branch, offer);
    // Sonraki branşa geç
    final nextPage = _currentBranchPage + 1;
    if (nextPage < _branches.length) {
      _pageCtrl.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gp      = context.watch<GameProvider>();
    final club    = gp.currentClub;
    final primary = _hex(club?.primaryColor ?? '', const Color(0xFFFFBF00));

    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, gp, primary, club),
            // Branş sekmeleri
            _BranchTabBar(
              branches: _branches,
              branchIcons: _branchIcons,
              currentIndex: _currentBranchPage,
              gp: gp,
              primary: primary,
              onTap: (i) {
                _pageCtrl.animateToPage(i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut);
              },
            ),
            const SizedBox(height: 4),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _branches.length,
                onPageChanged: (i) => setState(() => _currentBranchPage = i),
                itemBuilder: (ctx, i) {
                  final branch  = _branches[i];
                  final remaining = gp.namingRightsRemaining(branch);

                  // Aktif naming rights sözleşmesi → kilitli sayfa
                  if (remaining > 0) {
                    return _LockedBranchPage(
                      branch: branch,
                      icon: _branchIcons[branch]!,
                      activeSponsor: gp.activeSponsor(branch),
                      remainingSeasons: remaining,
                      primary: primary,
                    );
                  }

                  final offers = gp.sponsorOffersForSeason[branch] ?? [];
                  final active = gp.activeSponsor(branch);
                  return _BranchOfferPage(
                    branch: branch,
                    icon:   _branchIcons[branch]!,
                    offers: offers,
                    activeOffer: active?.offer,
                    primary: primary,
                    onSelect: (offer) => _selectSponsor(gp, branch, offer),
                  );
                },
              ),
            ),
            _buildBottomBar(context, gp, primary),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext ctx, GameProvider gp, Color primary, dynamic club) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEZON SPONSORLUKLARI',
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primary,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Her Branş İçin Sponsorunu Seç',
            style: GoogleFonts.rajdhani(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Seçilen sponsor sezon boyunca forma/kartta görünür ve '
            'galibiyet primlerini otomatik öder.',
            style: GoogleFonts.rajdhani(
              fontSize: 13, color: const Color(0xFF8A9BB8), height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
      BuildContext ctx, GameProvider gp, Color primary) {
    final allSelected = gp.allSponsorsSelected;
    // Kilitli branşları da "seçildi" say
    final selectedCount = _branches
        .where((b) =>
            gp.activeSponsor(b) != null || gp.namingRightsRemaining(b) > 0)
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF111C33),
        border: Border(
          top: BorderSide(
            color: primary.withValues(alpha: 0.2), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: _branches
                .map((b) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        height: 4,
                        decoration: BoxDecoration(
                          color: (gp.activeSponsor(b) != null ||
                                gp.namingRightsRemaining(b) > 0)
                              ? primary
                              : const Color(0xFF2C3546),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$selectedCount / ${_branches.length} branş seçildi',
                style: GoogleFonts.rajdhani(
                  fontSize: 13,
                  color: const Color(0xFF8A9BB8),
                ),
              ),
              if (allSelected)
                Text(
                  '✓ Hazır!',
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF69F0AE),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: allSelected && !_isStartingSeason
                  ? () => _onStartSeason(ctx, gp)
                  : null,
              icon: _isStartingSeason
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF080F1E),
                      ),
                    )
                  : const Icon(Icons.rocket_launch_rounded),
              label: Text(
                _isStartingSeason ? 'Kaydediliyor...' : 'Sezona Başla',
                style: GoogleFonts.rajdhani(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: const Color(0xFF080F1E),
                disabledBackgroundColor: const Color(0xFF1E2D48),
                disabledForegroundColor: const Color(0xFF8A9BB8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: allSelected && !_isStartingSeason ? 6 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Branş sekme barı
// ---------------------------------------------------------------------------
class _BranchTabBar extends StatelessWidget {
  final List<String> branches;
  final Map<String, IconData> branchIcons;
  final int currentIndex;
  final GameProvider gp;
  final Color primary;
  final ValueChanged<int> onTap;

  const _BranchTabBar({
    required this.branches,
    required this.branchIcons,
    required this.currentIndex,
    required this.gp,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: branches.asMap().entries.map((e) {
          final i = e.key;
          final b = e.value;
          final isActive   = i == currentIndex;
          final isSelected = gp.activeSponsor(b) != null;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? primary.withValues(alpha: 0.15)
                      : const Color(0xFF111C33),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? primary.withValues(alpha: 0.5)
                        : const Color(0xFF1E2D48),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          branchIcons[b]!,
                          color: isActive ? primary : const Color(0xFF8A9BB8),
                          size: 20,
                        ),
                        if (isSelected)
                          Positioned(
                            right: -4, top: -4,
                            child: Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF69F0AE),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b,
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive ? primary : const Color(0xFF8A9BB8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kilitli branş sayfası (aktif naming rights)
// ---------------------------------------------------------------------------
class _LockedBranchPage extends StatelessWidget {
  final String branch;
  final IconData icon;
  final ActiveSponsor? activeSponsor;
  final int remainingSeasons;
  final Color primary;

  const _LockedBranchPage({
    required this.branch,
    required this.icon,
    required this.activeSponsor,
    required this.remainingSeasons,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final sponsor = activeSponsor;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111C33),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_rounded, color: primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              sponsor?.offer.sponsorName ?? '—',
              style: GoogleFonts.rajdhani(
                fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Stat İsim Hakkı — Aktif Sözleşme',
              style: GoogleFonts.rajdhani(
                fontSize: 14, color: primary, letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_rounded, color: primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Kalan Sözleşme: $remainingSeasons Sezon',
                    style: GoogleFonts.rajdhani(
                      fontSize: 15, fontWeight: FontWeight.w700, color: primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bu branş için sponsor anlaşması devam ediyor.\n'
              'Sözleşme bittiğinde yeni teklifler gelecek.',
              style: GoogleFonts.rajdhani(
                fontSize: 13, color: const Color(0xFF8A9BB8), height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tek branşın teklif sayfası
// ---------------------------------------------------------------------------
class _BranchOfferPage extends StatelessWidget {
  final String branch;
  final IconData icon;
  final List<SponsorOffer> offers;
  final SponsorOffer? activeOffer;
  final Color primary;
  final ValueChanged<SponsorOffer> onSelect;

  const _BranchOfferPage({
    required this.branch,
    required this.icon,
    required this.offers,
    required this.activeOffer,
    required this.primary,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      children: offers.map((offer) => _SponsorCard(
            offer: offer,
            isSelected: activeOffer?.id == offer.id,
            primary: primary,
            onSelect: () => onSelect(offer),
          )).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Sponsor Kartı
// ---------------------------------------------------------------------------
class _SponsorCard extends StatelessWidget {
  final SponsorOffer offer;
  final bool isSelected;
  final Color primary;
  final VoidCallback onSelect;

  const _SponsorCard({
    required this.offer,
    required this.isSelected,
    required this.primary,
    required this.onSelect,
  });

  static const _typeColors = {
    SponsorType.guaranteed:   Color(0xFF69F0AE),
    SponsorType.performance:  Color(0xFF4FC3F7),
    SponsorType.prestige:     Color(0xFFFFBF00),
    SponsorType.namingRights: Color(0xFFE040FB),
  };

  static const _typeIcons = {
    SponsorType.guaranteed:   Icons.verified_rounded,
    SponsorType.performance:  Icons.trending_up_rounded,
    SponsorType.prestige:     Icons.star_rounded,
    SponsorType.namingRights: Icons.stadium_rounded,
  };

  static Color _tierAccent(SponsorBrandTier t) => switch (t) {
        SponsorBrandTier.elite => const Color(0xFFE040FB),
        SponsorBrandTier.pro => const Color(0xFFFF9100),
        SponsorBrandTier.local => const Color(0xFF8A9BB8),
      };

  @override
  Widget build(BuildContext context) {
    final accent = _typeColors[offer.type]!;
    final icon   = _typeIcons[offer.type]!;
    final clause = offer.terminationClause;
    final isNR   = offer.isNamingRights;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: 0.12)
            : const Color(0xFF111C33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? accent.withValues(alpha: 0.7)
              : isNR
                  ? accent.withValues(alpha: 0.35)
                  : const Color(0xFF1E2D48),
          width: isSelected ? 2 : (isNR ? 1.5 : 1),
        ),
        boxShadow: isSelected || isNR
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: isSelected ? 0.2 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Naming rights özel banner
            if (isNR) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '⭐ STAT İSİM HAKKI — 3 SEZONLUK ANLAŞMA',
                      style: GoogleFonts.rajdhani(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: accent, letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            // Başlık
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.sponsorName,
                        style: GoogleFonts.rajdhani(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      // Tür + Sektör badge
                      Row(
                        children: [
                          _miniChip(offer.typeLabel, accent),
                          const SizedBox(width: 6),
                          _miniChip(offer.sector, const Color(0xFF8A9BB8)),
                          if (offer.brandTier != null) ...[
                            const SizedBox(width: 6),
                            _miniChip(
                              offer.brandTierLabel!,
                              _tierAccent(offer.brandTier!),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.black, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // Açıklama
            Text(
              offer.description,
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                color: const Color(0xFF8A9BB8),
                height: 1.5,
              ),
            ),
            // ⚠ Risk Şartı (fesih maddesi) — belirgin kırmızı
            if (clause != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFFF5252), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        clause,
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF5252),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Finansal özet
            Row(
              children: [
                _financeStat(
                  label: 'Peşinat',
                  value: _fmt(offer.upfrontPayment),
                  color: const Color(0xFF69F0AE),
                ),
                const SizedBox(width: 10),
                _financeStat(
                  label: offer.isNamingRights ? 'Yıllık Prim' : 'Galibiyet Primi',
                  value: offer.winBonus > 0 ? _fmt(offer.winBonus) : '—',
                  color: accent,
                ),
                if (offer.reputationBonus > 0) ...[
                  const SizedBox(width: 10),
                  _financeStat(
                    label: 'İtibar',
                    value: '+${offer.reputationBonus}',
                    color: const Color(0xFFFFBF00),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: isSelected ? null : onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? accent : accent,
                  foregroundColor: const Color(0xFF080F1E),
                  disabledBackgroundColor: accent.withValues(alpha: 0.3),
                  disabledForegroundColor: accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: isSelected ? 0 : 4,
                ),
                child: Text(
                  isSelected ? '✓ Seçildi' : 'Bu Sponsoru Seç',
                  style: GoogleFonts.rajdhani(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _financeStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                  fontSize: 10, color: const Color(0xFF8A9BB8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _miniChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
}

String _fmt(double amount) {
  if (amount.abs() >= 1000000) {
    return '€${(amount / 1000000).toStringAsFixed(2)}M';
  }
  if (amount.abs() >= 1000) {
    return '€${(amount / 1000).toStringAsFixed(0)}K';
  }
  return '€${amount.toStringAsFixed(0)}';
}
