import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../logic/game_provider.dart';
import '../models/global_club_catalog.dart';

void showTrophyRoomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return Consumer<GameProvider>(
        builder: (_, gp, _) => DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.38,
          maxChildSize: 0.94,
          expand: false,
          builder: (_, scrollController) =>
              _TrophyRoomBody(gp: gp, scrollController: scrollController),
        ),
      );
    },
  );
}

class _TrophyRoomBody extends StatelessWidget {
  final GameProvider gp;
  final ScrollController scrollController;

  const _TrophyRoomBody({
    required this.gp,
    required this.scrollController,
  });

  /// Katalog kimliği [BranchKeys.volleyball] = «Voleybol» yazımına uygun etiket.
  static String _branchLabel(String branchId, String branchFallback) {
    if (branchId == BranchKeys.volleyball || branchFallback == BranchKeys.volleyball) {
      return 'Voleybol';
    }
    if (branchId == BranchKeys.basketball || branchFallback == BranchKeys.basketball) {
      return 'Basketbol';
    }
    if (branchId == BranchKeys.football || branchFallback == BranchKeys.football) {
      return 'Futbol';
    }
    return branchFallback;
  }

  static IconData _iconForRank(int rank) {
    return switch (rank) {
      1 => Icons.emoji_events_rounded,
      2 => Icons.workspace_premium_rounded,
      3 => Icons.workspace_premium_rounded,
      _ => Icons.military_tech_rounded,
    };
  }

  static Color _colorForRank(int rank) {
    return switch (rank) {
      1 => const Color(0xFFFFBF00),
      2 => const Color(0xFFB0BEC5),
      3 => const Color(0xFFCD7F32),
      _ => const Color(0xFF8A9BB8),
    };
  }

  static String _rankOrdinalTr(int rank) {
    return switch (rank) {
      1 => 'Şampiyonluğu',
      2 => '2.liği',
      3 => '3.lüğü',
      _ => '$rank.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final trophies = gp.trophyRoom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111C33),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2C3546),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                const Icon(Icons.museum_rounded,
                    color: Color(0xFFFFBF00), size: 26),
                const SizedBox(width: 10),
                Text(
                  'Müze · Başarı salonu',
                  style: GoogleFonts.rajdhani(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              trophies.isEmpty
                  ? 'Henüz vitrin boş — herhangi bir branşta ligi ilk üçte bitirince madalya ve kupalar burada birikir.'
                  : 'Her kayıt sponsorluk nakit çarpanını +%5 güçlendirir (${trophies.length} eser). Altın / gümüş / bronz lig dereceleri birlikte sayılır.',
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                color: const Color(0xFF8A9BB8),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: trophies.isEmpty
                ? Center(
                    child: Icon(Icons.emoji_events_outlined,
                        size: 72, color: Colors.white.withValues(alpha: 0.12)),
                  )
                : GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: trophies.length,
                    itemBuilder: (_, i) {
                      final t = trophies[i];
                      final rankColor = _colorForRank(t.rank);
                      final branchName =
                          _branchLabel(t.branchId, t.branch);
                      final subtitle =
                          '${t.completedSeasonYearMark} $branchName ${_rankOrdinalTr(t.rank)}';

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151E32),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: rankColor.withValues(alpha: 0.45)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_iconForRank(t.rank),
                                size: 42, color: rankColor),
                            const SizedBox(height: 8),
                            Text(
                              t.awardTitle,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.rajdhani(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.rajdhani(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFCFD8E9),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.leagueName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.rajdhani(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B7A92),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
