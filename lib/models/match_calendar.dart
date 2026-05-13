/// Lig fikstür satırı (gelecek maç kartı için).
class MatchSchedule {
  final String branch;
  /// Sezon takvimindeki hafta (1…38).
  final int calendarWeek;
  /// Bu branşın kaçıncı lig maç haftası (1-tabanlı, basket/voley sıra).
  final int leagueRoundIndex;
  final String homeTeam;
  final String awayTeam;
  /// Kulüp ismiyle eşleşirse bu satır oyuncuyu ilgilendirir.
  final bool involvesPlayerClub;

  const MatchSchedule({
    required this.branch,
    required this.calendarWeek,
    required this.leagueRoundIndex,
    required this.homeTeam,
    required this.awayTeam,
    required this.involvesPlayerClub,
  });

  Map<String, dynamic> toMap() => {
        'branch': branch,
        'calendarWeek': calendarWeek,
        'leagueRoundIndex': leagueRoundIndex,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'involvesPlayerClub': involvesPlayerClub,
      };

  factory MatchSchedule.fromMap(Map<String, dynamic> m) {
    return MatchSchedule(
      branch: m['branch'] as String,
      calendarWeek: m['calendarWeek'] as int,
      leagueRoundIndex: m['leagueRoundIndex'] as int,
      homeTeam: m['homeTeam'] as String,
      awayTeam: m['awayTeam'] as String,
      involvesPlayerClub: m['involvesPlayerClub'] as bool? ?? false,
    );
  }
}

/// Oynanmış maç arşivi (skor dahil).
class MatchResult {
  final String branch;
  final int seasonNumber;
  final int calendarWeek;
  final String homeTeam;
  final String awayTeam;
  final int homeGoals;
  final int awayGoals;
  final bool playerIsHomeSlot;
  final String playerClubName;
  /// Oyuncu tarafından bakılan skor sırası: (bizim için attığımız, yediğimiz).
  final int goalsFor;
  final int goalsAgainst;

  const MatchResult({
    required this.branch,
    required this.seasonNumber,
    required this.calendarWeek,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeGoals,
    required this.awayGoals,
    required this.playerIsHomeSlot,
    required this.playerClubName,
    required this.goalsFor,
    required this.goalsAgainst,
  });

  String get scoreLineTotal => '$homeGoals · $awayGoals';

  Map<String, dynamic> toMap() => {
        'branch': branch,
        'seasonNumber': seasonNumber,
        'calendarWeek': calendarWeek,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'homeGoals': homeGoals,
        'awayGoals': awayGoals,
        'playerIsHomeSlot': playerIsHomeSlot,
        'playerClubName': playerClubName,
        'goalsFor': goalsFor,
        'goalsAgainst': goalsAgainst,
      };

  factory MatchResult.fromMap(Map<String, dynamic> m) {
    return MatchResult(
      branch: m['branch'] as String,
      seasonNumber: m['seasonNumber'] as int,
      calendarWeek: m['calendarWeek'] as int,
      homeTeam: m['homeTeam'] as String,
      awayTeam: m['awayTeam'] as String,
      homeGoals: m['homeGoals'] as int,
      awayGoals: m['awayGoals'] as int,
      playerIsHomeSlot: m['playerIsHomeSlot'] as bool? ?? false,
      playerClubName: m['playerClubName'] as String,
      goalsFor: m['goalsFor'] as int,
      goalsAgainst: m['goalsAgainst'] as int,
    );
  }
}
