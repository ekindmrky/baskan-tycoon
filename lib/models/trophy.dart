import 'global_club_catalog.dart';

/// Müze vitrininde saklanan lig kürsüsü (1–3) kaydı.
/// [branchId] ile [BranchKeys] ([GlobalClubCatalog]) hizalıdır.
class Trophy {
  Trophy({
    required this.branch,
    required this.branchId,
    required this.rank,
    required this.seasonCompleted,
    required this.leagueName,
    required this.completedSeasonYearMark,
  }) : assert(rank >= 1 && rank <= 3);

  /// Görünen branş adı (örn. `CountryData` sabitleri ile aynı Türkçe etiket).
  final String branch;

  /// Katalog / kayıt kimliği — [BranchKeys] ile uyumlu (`Futbol`, `Basketbol`, `Voleybol`).
  final String branchId;

  /// Lig sıralaması: 1 şampiyonluk, 2 ikincilik, 3 üçüncülük.
  final int rank;

  /// Oyun içi kampanya takvimi son yılı (müze etiketi).
  final int completedSeasonYearMark;

  /// Biten sezonun numarası (`GameProvider.seasonNumber` sezon sonunda).
  final int seasonCompleted;

  final String leagueName;

  /// Vitrin için kısa derece adı.
  String get awardTitle => switch (rank) {
        1 => 'Altın Kupa',
        2 => 'Gümüş Madalya',
        3 => 'Bronz Madalya',
        _ => 'Derece',
      };

  Map<String, dynamic> toMap() => {
        'branch': branch,
        'branchId': branchId,
        'rank': rank,
        'seasonCompleted': seasonCompleted,
        'leagueName': leagueName,
        'completedSeasonYearMark': completedSeasonYearMark,
      };

  /// JSON uyumluluğu için [toMap] ile aynı yapı.
  Map<String, dynamic> toJson() => toMap();

  factory Trophy.fromMap(Map<String, dynamic> m) {
    final branchStr = m['branch'] as String? ?? BranchKeys.football;
    final migratedRank = (m['rank'] as num?)?.toInt() ?? 1;
    final rawId = m['branchId'] as String?;
    final id = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : Trophy._branchIdFromLegacyBranch(branchStr);
    return Trophy(
      branch: branchStr,
      branchId: id,
      rank: migratedRank.clamp(1, 3),
      seasonCompleted: (m['seasonCompleted'] as num).toInt(),
      leagueName: m['leagueName'] as String,
      completedSeasonYearMark: (m['completedSeasonYearMark'] as num?)?.toInt() ??
          ((m['year'] as num?)?.toInt() ??
              (m['seasonCompleted'] as num).toInt()),
    );
  }

  factory Trophy.fromJson(Map<String, dynamic> json) => Trophy.fromMap(json);

  static String _branchIdFromLegacyBranch(String branch) => switch (branch) {
        BranchKeys.football ||
        'football' ||
        'Futbol' =>
          BranchKeys.football,
        BranchKeys.basketball ||
        'basketball' ||
        'Basketbol' =>
          BranchKeys.basketball,
        BranchKeys.volleyball ||
        'volleyball' ||
        'Voleybol' =>
          BranchKeys.volleyball,
        _ => branch,
      };
}
