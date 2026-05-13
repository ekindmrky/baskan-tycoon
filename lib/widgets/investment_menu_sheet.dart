import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:presidento/logic/game_provider.dart';
import 'package:presidento/models/club.dart';

Color _hex(String hex, Color fallback) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return fallback;
  }
}

String _fmt(double amount) {
  if (amount.abs() >= 1000000) return '€${(amount / 1000000).toStringAsFixed(2)}M';
  if (amount.abs() >= 1000)    return '€${(amount / 1000).toStringAsFixed(0)}K';
  return '€${amount.toStringAsFixed(0)}';
}

void showInvestmentMenu(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _InvestmentMenuSheet(),
  );
}

class _InvestmentMenuSheet extends StatefulWidget {
  const _InvestmentMenuSheet();

  @override
  State<_InvestmentMenuSheet> createState() => _InvestmentMenuSheetState();
}

class _InvestmentMenuSheetState extends State<_InvestmentMenuSheet> {
  static const _topUpAmounts = [25000.0, 50000.0, 100000.0];

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
  static const _branchAccents = {
    CountryData.football:   Color(0xFF69F0AE),
    CountryData.basketball: Color(0xFF4FC3F7),
    CountryData.volleyball: Color(0xFFFFBF00),
  };

  String _lastMessage = '';
  bool   _lastSuccess  = false;

  void _onPurchase(GameProvider gp, String branch, InvestmentType type) {
    final success = gp.purchaseInvestment(branch, type);
    setState(() {
      _lastSuccess = success;
      _lastMessage = success
          ? '✓ Yatırım tamamlandı!'
          : gp.currentClub != null
              ? '✗ Yetersiz kasa veya maksimum seviye.'
              : '✗ Hata.';
    });
  }

  void _onTopUp(GameProvider gp, String branch, double amount) {
    final success = gp.topUpBranchBudgetFromTreasury(branch, amount);
    setState(() {
      _lastSuccess = success;
      _lastMessage = success
          ? '✓ ${_fmt(amount)} branş bütçesine aktarıldı.'
          : gp.currentClub != null &&
                  (gp.currentClub!.treasury + 0.01 < amount)
              ? '✗ Kasa bu tutarı karşılamıyor.'
              : '✗ İşlem yapılamadı.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final gp      = context.watch<GameProvider>();
    final club    = gp.currentClub;
    final primary = _hex(club?.primaryColor ?? '', const Color(0xFFFFBF00));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111C33),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildHeader(primary),
            if (_lastMessage.isNotEmpty)
              _FeedbackBar(message: _lastMessage, isSuccess: _lastSuccess),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: _branches.map((branch) {
                  return _BranchInvestmentSection(
                    branch: branch,
                    icon:   _branchIcons[branch]!,
                    accent: _branchAccents[branch]!,
                    gp:     gp,
                    club:   club,
                    topUpAmounts: _topUpAmounts,
                    onPurchase: (type) => _onPurchase(gp, branch, type),
                    onTopUp: (amt) => _onTopUp(gp, branch, amt),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color primary) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3546),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.construction_rounded, color: primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Kulübü Geliştir',
                  style: GoogleFonts.rajdhani(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tesis, altyapı ve pazarlama yatırımları.\n'
              'Kasadan kalıcı olarak branş bütçesi de artırabilirsin (kasadan düşer).',
              style: GoogleFonts.rajdhani(
                  fontSize: 12.5, color: const Color(0xFF8A9BB8), height: 1.5),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
class _FeedbackBar extends StatelessWidget {
  final String message;
  final bool   isSuccess;
  const _FeedbackBar({required this.message, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    final color = isSuccess
        ? const Color(0xFF69F0AE)
        : const Color(0xFFFF5252);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: GoogleFonts.rajdhani(
            fontSize: 14, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _BranchInvestmentSection extends StatelessWidget {
  final String   branch;
  final IconData icon;
  final Color    accent;
  final GameProvider gp;
  final Club?    club;
  final List<double> topUpAmounts;
  final ValueChanged<InvestmentType> onPurchase;
  final ValueChanged<double> onTopUp;

  const _BranchInvestmentSection({
    required this.branch,
    required this.icon,
    required this.accent,
    required this.gp,
    required this.club,
    required this.topUpAmounts,
    required this.onPurchase,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    final leagueIdx  = gp.branchLeagueIndex(branch);
    final leagueName = BranchLeagueData.leagues[branch]?[leagueIdx] ?? branch;

    final facilLvl = gp.facilityLevel(branch);
    final infraLvl = gp.infrastructureLevel(branch);
    final mktLvl   = gp.marketingLevel(branch);

    // Verimlilik katsayıları
    final facilEff = InvestmentCatalog.efficiencyFactor(facilLvl, leagueIdx);
    final infraEff = InvestmentCatalog.efficiencyFactor(infraLvl, leagueIdx);
    final mktEff   = InvestmentCatalog.efficiencyFactor(mktLvl,   leagueIdx);

    // Tesis uyarısı: mevcut tesis seviyesi lig için yeterli mi?
    final facilWarning = facilLvl > 0 && facilEff < 1.0
        ? 'Tesis seviyesi yetersiz! Verim %${(facilEff * 100).toInt()} düştü.'
        : null;

    double branchBudget = 0;
    final c = club;
    if (c != null) {
      for (final b in c.branches) {
        if (b.name == branch) {
          branchBudget = b.budget;
          break;
        }
      }
    }
    final treasury = c?.treasury ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2744),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branş başlığı + lig
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                branch,
                style: GoogleFonts.rajdhani(
                  fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· $leagueName',
                style: GoogleFonts.rajdhani(
                  fontSize: 12, color: const Color(0xFF8A9BB8)),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            'Mevcut branş bütçesi: ${_fmt(branchBudget)}',
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              color: const Color(0xFF8A9BB8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kasadan kalıcı branş bütçesi artışı (bütçe düşürme yok)',
            style: GoogleFonts.rajdhani(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < topUpAmounts.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _TopUpChip(
                    label: '+${_fmt(topUpAmounts[i])}',
                    accent: accent,
                    enabled: treasury + 0.01 >= topUpAmounts[i],
                    onTap: () => onTopUp(topUpAmounts[i]),
                  ),
                ),
              ],
            ],
          ),

          // Tesis uyarı bandı
          if (facilWarning != null) ...[
            const SizedBox(height: 8),
            _EfficiencyWarning(message: facilWarning),
          ],

          const SizedBox(height: 12),

          // Tesis
          _InvestmentRow(
            type:         InvestmentType.facility,
            label:        'Tesis Geliştirme',
            icon:         Icons.home_repair_service_rounded,
            currentLevel: facilLvl,
            efficiency:   facilLvl > 0 ? facilEff : null,
            accent:       const Color(0xFFFF7043),
            treasury:     club?.treasury ?? 0,
            onPurchase:   () => onPurchase(InvestmentType.facility),
          ),
          const SizedBox(height: 8),

          // Altyapı
          _InvestmentRow(
            type:         InvestmentType.infrastructure,
            label:        'Altyapı Geliştirme',
            icon:         Icons.stadium_rounded,
            currentLevel: infraLvl,
            efficiency:   infraLvl > 0 ? infraEff : null,
            accent:       accent,
            treasury:     club?.treasury ?? 0,
            onPurchase:   () => onPurchase(InvestmentType.infrastructure),
          ),
          const SizedBox(height: 8),

          // Pazarlama
          _InvestmentRow(
            type:         InvestmentType.marketing,
            label:        'Pazarlama & Tanıtım',
            icon:         Icons.campaign_rounded,
            currentLevel: mktLvl,
            efficiency:   mktLvl > 0 ? mktEff : null,
            accent:       const Color(0xFFFFBF00),
            treasury:     club?.treasury ?? 0,
            onPurchase:   () => onPurchase(InvestmentType.marketing),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _TopUpChip extends StatelessWidget {
  final String label;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  const _TopUpChip({
    required this.label,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.12)
                : const Color(0xFF2C3546),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  enabled ? accent.withValues(alpha: 0.35) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: enabled ? accent : const Color(0xFF8A9BB8),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _EfficiencyWarning extends StatelessWidget {
  final String message;
  const _EfficiencyWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5252).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFF5252), size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFF5252),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _InvestmentRow extends StatelessWidget {
  final InvestmentType type;
  final String         label;
  final IconData       icon;
  final int            currentLevel;
  final double?        efficiency;   // null = henüz satın alınmadı
  final Color          accent;
  final double         treasury;
  final VoidCallback   onPurchase;

  const _InvestmentRow({
    required this.type,
    required this.label,
    required this.icon,
    required this.currentLevel,
    required this.efficiency,
    required this.accent,
    required this.treasury,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final nextTier  = InvestmentCatalog.nextTier(type, currentLevel);
    final isMaxed   = nextTier == null;
    final canAfford = nextTier != null && treasury >= nextTier.cost;

    // Etki açıklaması: bir sonraki seviyenin bonusu
    String effectText;
    if (isMaxed) {
      effectText = 'Maksimum seviye';
    } else {
      effectText = nextTier.effectDescription;
    }

    // Verimlilik yüzdesi (zaten satın alınmışsa göster)
    final String? effText = efficiency != null
        ? 'Verim: %${(efficiency! * 100).toInt()}'
        : null;
    final effColor = (efficiency ?? 1.0) >= 0.8
        ? const Color(0xFF69F0AE)
        : (efficiency ?? 1.0) >= 0.5
            ? const Color(0xFFFFBF00)
            : const Color(0xFFFF5252);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111C33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.rajdhani(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (effText != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: effColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          effText,
                          style: GoogleFonts.rajdhani(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: effColor),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  effectText,
                  style: GoogleFonts.rajdhani(
                      fontSize: 12, color: const Color(0xFF8A9BB8)),
                ),
              ],
            ),
          ),
          // 5 seviye noktası
          Row(
            children: List.generate(InvestmentCatalog.maxLevel, (i) =>
              Container(
                margin: const EdgeInsets.only(left: 3),
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: i < currentLevel ? accent : const Color(0xFF2C3546),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Satın al butonu
          if (!isMaxed)
            GestureDetector(
              onTap: canAfford ? onPurchase : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: canAfford
                      ? accent.withValues(alpha: 0.2)
                      : const Color(0xFF2C3546),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: canAfford
                        ? accent.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  _fmt(nextTier.cost),
                  style: GoogleFonts.rajdhani(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: canAfford ? accent : const Color(0xFF8A9BB8),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'MAX',
                style: GoogleFonts.rajdhani(
                  fontSize: 12, fontWeight: FontWeight.w700, color: accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
