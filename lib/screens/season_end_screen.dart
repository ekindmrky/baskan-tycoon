import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:presidento/logic/game_provider.dart';
import 'package:presidento/screens/main_menu_screen.dart';

// Lig kürsüsü müzesi: her branş için ayrı Trophy kaydı GameProvider._resolveSeasonEnd
// içinde eklenir (BranchKeys / global_club_catalog ile hizalı branchId).

Color _hex(String hex, Color fallback) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return fallback;
  }
}

class SeasonEndScreen extends StatelessWidget {
  const SeasonEndScreen({super.key});

  static const _branchIcons = {
    CountryData.football: Icons.sports_soccer_rounded,
    CountryData.basketball: Icons.sports_basketball_rounded,
    CountryData.volleyball: Icons.sports_volleyball_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final club = gp.currentClub;
    final results = gp.lastSeasonResults ?? [];
    final scheme = Theme.of(context).colorScheme;

    final clubAccent = _hex(club?.primaryColor ?? '', const Color(0xFF38BDF8));

    final anyPromoted = results.any((r) => r.promoted);
    final totalPoints =
        results.fold(0, (sum, r) => sum + r.totalPoints);

    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Başlık ──────────────────────────────────────────────────
              _buildHeader(clubAccent, anyPromoted, club),
              const SizedBox(height: 28),

              // ── Genel istatistik şeridi ──────────────────────────────────
              _buildStatRow(scheme.primary, totalPoints, results),
              const SizedBox(height: 28),

              // ── Branş sonuçları ──────────────────────────────────────────
              Text(
                'BRANŞ DEĞERLENDİRMESİ',
                style: GoogleFonts.rajdhani(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8A9BB8),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              ...results.map(
                (r) => _BranchResultCard(
                  result: r,
                  icon: _branchIcons[r.branch] ?? Icons.sports,
                  accent: scheme.primary,
                ),
              ),
              const SizedBox(height: 28),

              // ── Sonuç mesajı ─────────────────────────────────────────────
              _buildVerdict(anyPromoted),
              const SizedBox(height: 32),

              // ── Aksiyonlar ───────────────────────────────────────────────
              _buildActions(context, gp, scheme),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------

  Widget _buildHeader(
    Color clubAccent,
    bool anyPromoted,
    dynamic club,
  ) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF151E30),
            shape: BoxShape.circle,
            border: Border.all(
              color: clubAccent.withValues(alpha: 0.85),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: clubAccent.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            anyPromoted
                ? Icons.emoji_events_rounded
                : Icons.shield_outlined,
            color: const Color(0xFFE2E8F0),
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sezon Sonu Değerlendirmesi',
                style: GoogleFonts.rajdhani(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 2,
                width: 72,
                decoration: BoxDecoration(
                  color: clubAccent.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                club?.name ?? '',
                style: GoogleFonts.rajdhani(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    Color accent,
    int totalPoints,
    List<BranchSeasonResult> results,
  ) {
    final promoted = results.where((r) => r.promoted).length;
    final cupChampions =
        results.where((r) => r.cupProgress.contains('Şampiyon')).length;

    return Row(
      children: [
        _StatTile(
          label: 'Toplam Puan',
          value: '$totalPoints',
          icon: Icons.stars_rounded,
          color: accent,
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'Küme Atlayan',
          value: '$promoted / ${results.length}',
          icon: Icons.arrow_upward_rounded,
          color: promoted > 0
              ? const Color(0xFF69F0AE)
              : const Color(0xFF8A9BB8),
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'Kupa Şamp.',
          value: '$cupChampions',
          icon: Icons.emoji_events_rounded,
          color: cupChampions > 0
              ? const Color(0xFFFFBF00)
              : const Color(0xFF8A9BB8),
        ),
      ],
    );
  }

  Widget _buildVerdict(bool anyPromoted) {
    final (icon, title, subtitle, color) = anyPromoted
        ? (
            Icons.trending_up_rounded,
            'Tebrikler!',
            'Küme atlamayı başaran branşlarınız yeni sezona üst ligde başlayacak.',
            const Color(0xFF69F0AE),
          )
        : (
            Icons.sports_score_rounded,
            'Sezon Tamamlandı',
            'Bu sezon küme atlamak için yeterli puan toplanamadı. Bir sonraki sezon için bütçeleri gözden geçir.',
            const Color(0xFFFFBF00),
          );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.rajdhani(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.rajdhani(
                    fontSize: 14,
                    color: const Color(0xFF8A9BB8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
      BuildContext context, GameProvider gp, ColorScheme scheme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.replay_rounded),
            label: Text(
              'Yeni Sezon Başlat',
              style: GoogleFonts.rajdhani(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              shadowColor: scheme.primary.withValues(alpha: 0.4),
            ),
            onPressed: () async {
              await gp.saveGame();
              gp.startNewSeason();
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: Text(
              'Ana Menüye Dön',
              style: GoogleFonts.rajdhani(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8A9BB8),
              side: const BorderSide(color: Color(0xFF2C3546)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              await gp.saveGame();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainMenuScreen()),
                (_) => false,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Branş sonuç kartı
// ---------------------------------------------------------------------------
class _BranchResultCard extends StatelessWidget {
  final BranchSeasonResult result;
  final IconData icon;
  final Color accent;

  const _BranchResultCard({
    required this.result,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final promoted = result.promoted;
    final relegated = result.relegated;
    final statusColor = promoted
        ? const Color(0xFF69F0AE)
        : relegated
            ? const Color(0xFFFF7043)
            : const Color(0xFF8A9BB8);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111C33),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.branch,
                  style: GoogleFonts.rajdhani(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${result.newLeagueName} · Tablo: ${result.tableRank}. sıra',
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    color: const Color(0xFF8A9BB8),
                  ),
                ),
              ],
            ),
          ),
              Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${result.totalPoints} puan',
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              // Lig sonucu rozeti
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      promoted
                          ? Icons.arrow_upward_rounded
                          : relegated
                              ? Icons.arrow_downward_rounded
                              : Icons.horizontal_rule_rounded,
                      color: statusColor,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      promoted
                          ? 'Küme Atladı'
                          : relegated
                              ? 'Kümeden Düştü'
                              : 'Aynı Ligde',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Kupa sonucu rozeti
              _CupProgressBadge(label: result.cupProgress),
              if (result.rankingBonus > 0) ...[
                const SizedBox(height: 4),
                _RankingBonusBadge(amount: result.rankingBonus),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kupa progress rozeti
// ---------------------------------------------------------------------------
class _CupProgressBadge extends StatelessWidget {
  final String label;
  const _CupProgressBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final isChampion = label.contains('Şampiyon');
    final color = isChampion
        ? const Color(0xFFFFBF00)
        : const Color(0xFF8A9BB8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isChampion
                ? Icons.emoji_events_rounded
                : Icons.emoji_events_outlined,
            color: color,
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 11,
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
// Sıralama bonus rozeti
// ---------------------------------------------------------------------------
class _RankingBonusBadge extends StatelessWidget {
  final double amount;
  const _RankingBonusBadge({required this.amount});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF4FC3F7);
    String fmt(double v) => v >= 1000000
        ? '€${(v / 1000000).toStringAsFixed(1)}M'
        : '€${(v / 1000).toStringAsFixed(0)}K';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.leaderboard_rounded, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            'Sıralama Primi +${fmt(amount)}',
            style: GoogleFonts.rajdhani(
              fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// İstatistik tile
// ---------------------------------------------------------------------------
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.rajdhani(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                fontSize: 10,
                color: const Color(0xFF8A9BB8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
