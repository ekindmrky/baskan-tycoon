import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../logic/game_provider.dart';
import '../models/models.dart';

/// Branşlar arası lig puan durumu (Dashboard'dan çağrılır).
void showLeagueStandingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return Consumer<GameProvider>(
        builder: (context, gp, child) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.45,
          maxChildSize: 0.96,
          expand: false,
          builder: (context2, scrollController) => _LeagueStandingsBody(gp: gp),
        ),
      );
    },
  );
}

class _LeagueStandingsBody extends StatelessWidget {
  final GameProvider gp;

  const _LeagueStandingsBody({
    required this.gp,
  });

  static const _branches = [
    CountryData.football,
    CountryData.basketball,
    CountryData.volleyball,
  ];

  static const _accents = {
    CountryData.football: Color(0xFF69F0AE),
    CountryData.basketball: Color(0xFF4FC3F7),
    CountryData.volleyball: Color(0xFFFFBF00),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111C33),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: DefaultTabController(
        length: _branches.length,
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
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Row(
                children: [
                  Icon(Icons.table_chart_rounded,
                      color: scheme.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Puan Durumu',
                    style: GoogleFonts.rajdhani(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.52),
              indicatorColor: scheme.primary,
              dividerColor: const Color(0xFF263243),
              tabs: [
                Tab(text: _branches[0]),
                Tab(text: _branches[1]),
                Tab(text: _branches[2]),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final b in _branches)
                    _StandingsTable(
                      gp: gp,
                      branch: b,
                      branchStripe: _accents[b]!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final GameProvider gp;
  final String branch;
  /// Sadece lig adı şeridi — tablo satırı vurgusu uygulama primary ile.
  final Color branchStripe;

  const _StandingsTable({
    required this.gp,
    required this.branch,
    required this.branchStripe,
  });

  @override
  Widget build(BuildContext context) {
    final rows = gp.standingsForBranch(branch);
    final league = gp.branchLeagueName(branch);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 36),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: branchStripe.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                league,
                style: GoogleFonts.rajdhani(
                  fontSize: 13,
                  color: const Color(0xFFCBD5E1),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Tablo yüklendiğinde görünecek.',
                style: GoogleFonts.rajdhani(color: const Color(0xFF8A9BB8)),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (_, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minWidth: constraints.maxWidth.clamp(360, 920)),
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFF1A2744)),
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 48,
                  columnSpacing: 10,
                  columns: [
                    _col('#'),
                    _col('Takım'),
                    _col('O'),
                    _col('G'),
                    _col('B'),
                    _col('M'),
                    _col('Ağ'),
                    _col('Y'),
                    _col('Av'),
                    _col('P'),
                  ],
                  rows: List.generate(rows.length, (i) {
                    final e = rows[i];
                    final rank = i + 1;
                    final isPlayer = e.isPlayer;
                    return DataRow(
                      color: WidgetStateProperty.all(
                        isPlayer
                            ? scheme.primary.withValues(alpha: 0.10)
                            : const Color(0xFF151E32),
                      ),
                      cells: [
                        DataCell(Text('$rank',
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.w700,
                              color: isPlayer
                                  ? scheme.primary
                                  : Colors.white70))),
                        DataCell(
                          Tooltip(
                            message:
                                '${e.teamName} — ${_standingDetailLines(e)}',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    _showStandingClubSheet(context, e),
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 200,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: Text(
                                      e.teamName,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                      style: GoogleFonts.rajdhani(
                                        fontWeight: isPlayer
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(_cell('${e.played}')),
                        DataCell(_cell('${e.wins}')),
                        DataCell(_cell('${e.draws}')),
                        DataCell(_cell('${e.losses}')),
                        DataCell(_cell('${e.goalsFor}')),
                        DataCell(_cell('${e.goalsAgainst}')),
                        DataCell(Text(
                          '${e.goalDifference}',
                          style: GoogleFonts.rajdhani(
                            fontSize: 13,
                            color: const Color(0xFFCFD8E9),
                          ),
                        )),
                        DataCell(Text(
                          '${e.points}',
                          style: GoogleFonts.rajdhani(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color:
                                isPlayer ? scheme.primary : Colors.white,
                          ),
                        )),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
      ],
    );
  }

  DataColumn _col(String label) => DataColumn(
        label: Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF8A9BB8),
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _cell(String t) => Text(
        t,
        style:
            GoogleFonts.rajdhani(fontSize: 13, color: const Color(0xFFCFD8E9)),
      );
}

void _showStandingClubSheet(BuildContext context, LeagueStandingEntry e) {
  final scheme = Theme.of(context).colorScheme;

  Widget line(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8A9BB8),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.rajdhani(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  final titleType =
      e.isPlayer ? 'Oyuncu kulübü' : (e.teamType?.label ?? '—');

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF121A28),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(22, 16, 22, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.shield_rounded, color: scheme.primary, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.teamName,
                    style: GoogleFonts.rajdhani(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (e.isPlayer)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'Sen',
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            line(
              Icons.emoji_events_rounded,
              'Lig şampiyonluğu (miras)',
              '${e.titlesCount}',
            ),
            line(Icons.category_rounded, 'Kulüp tipi', titleType),
            line(
              Icons.account_balance_wallet_rounded,
              'Bütçe / finans sınıfı',
              e.budgetClass?.label ?? (e.isPlayer ? 'Profil ile belirlenir' : '—'),
            ),
            if (!e.isPlayer && e.basePower > 0)
              line(Icons.speed_rounded, 'Taban güç', '${e.basePower}'),
            if (e.globalId != null && e.globalId!.isNotEmpty)
              line(Icons.tag_rounded, 'Katalog ID', e.globalId!),
            const SizedBox(height: 4),
            Text(
              'Haftalık form: ${e.weeklyForm >= 0 ? '+' : ''}${e.weeklyForm}',
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    },
  );
}

String _standingDetailLines(LeagueStandingEntry e) {
  if (e.isPlayer) {
    return 'Senin kulübün · Lig şampiyonluğu: ${e.titlesCount}';
  }
  final tier = e.teamType?.label ?? '—';
  final money = e.budgetClass?.label ?? '—';
  return '$tier · $money · Kupa: ${e.titlesCount} · Güç: ${e.basePower}';
}
