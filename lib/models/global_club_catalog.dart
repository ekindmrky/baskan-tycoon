// Branşlar arası kimliği ortak olan (veya tek branşı domine eden) bot kulüp şemaları.

import 'dart:collection';

import 'bot_team.dart';

/// `GameProvider.CountryData` ile aynı sabit dizeler.
abstract final class BranchKeys {
  static const football = 'Futbol';
  static const basketball = 'Basketbol';
  static const volleyball = 'Voleybol';
}

/// Bir branşa özel görünen isim + güç seviyesi.
class BranchClubSpec {
  const BranchClubSpec({
    required this.displayName,
    required this.tier,
  });

  final String displayName;
  final TeamType tier;
}

final class GlobalClubTemplate {
  const GlobalClubTemplate({
    required this.globalId,
    required this.bigThreeDev,
    this.football,
    this.basketball,
    this.volleyball,
  });

  final String globalId;

  /// "Big three" kulüpler: her branştaki devler · çok yüksek bütçe + sezonluk güç takviyesi.
  final bool bigThreeDev;

  final BranchClubSpec? football;
  final BranchClubSpec? basketball;
  final BranchClubSpec? volleyball;

  BranchClubSpec? specForBranch(String branch) {
    if (branch == BranchKeys.football) return football;
    if (branch == BranchKeys.basketball) return basketball;
    if (branch == BranchKeys.volleyball) return volleyball;
    return null;
  }

  bool participatesInBranch(String branch) =>
      specForBranch(branch) != null;

  /// Tek branşa özel güç odaklı kulüpler.
  bool get isSpecialistOneBranch {
    final c = [
      football != null,
      basketball != null,
      volleyball != null,
    ].where((x) => x).length;
    return c == 1;
  }
}

/// Oyundaki küresel şablonlar (Big 3 parodileri + uzman kulüp).
abstract final class GlobalClubCatalog {
  static const GlobalClubTemplate devGoldenEagles = GlobalClubTemplate(
    globalId: 'dev1_cartal',
    bigThreeDev: true,
    football: BranchClubSpec(
      displayName: 'İstanbul Kartalları',
      tier: TeamType.elite,
    ),
    basketball: BranchClubSpec(
      displayName: 'Kartal Basket',
      tier: TeamType.elite,
    ),
    volleyball: BranchClubSpec(
      displayName: 'Dişi Kartallar',
      tier: TeamType.elite,
    ),
  );

  static const GlobalClubTemplate devCoastalGiants = GlobalClubTemplate(
    globalId: 'dev2_ege',
    bigThreeDev: true,
    football: BranchClubSpec(
      displayName: 'Ege Denizgüzü FK',
      tier: TeamType.elite,
    ),
    basketball: BranchClubSpec(
      displayName: 'Ege Fırtına Basketbol',
      tier: TeamType.elite,
    ),
    volleyball: BranchClubSpec(
      displayName: 'Ege Gücü VC',
      tier: TeamType.elite,
    ),
  );

  static const GlobalClubTemplate devCapitalTitans = GlobalClubTemplate(
    globalId: 'dev3_baskent',
    bigThreeDev: true,
    football: BranchClubSpec(
      displayName: 'Başkent Yıldırım SK',
      tier: TeamType.elite,
    ),
    basketball: BranchClubSpec(
      displayName: 'Ankara Potası',
      tier: TeamType.elite,
    ),
    volleyball: BranchClubSpec(
      displayName: 'Orta Anadolu Voleybol',
      tier: TeamType.elite,
    ),
  );

  /// Sadece basketbolda güçlü uzman kulüp.
  static const GlobalClubTemplate specialistBasketAnadolu = GlobalClubTemplate(
    globalId: 'spec_anadolu_stars_bb',
    bigThreeDev: false,
    football: null,
    basketball: BranchClubSpec(
      displayName: 'Anadolu Yıldızları',
      tier: TeamType.elite,
    ),
    volleyball: null,
  );

  /// Sıra: üç dev kulüpten sonra kalan sabit küresel yüzler.
  static const List<GlobalClubTemplate> allFixed = [
    devGoldenEagles,
    devCoastalGiants,
    devCapitalTitans,
    specialistBasketAnadolu,
  ];

  static Set<String> get bigThreeGlobalIds => {
        devGoldenEagles.globalId,
        devCoastalGiants.globalId,
        devCapitalTitans.globalId,
      };

  static bool isBigThreeFranchise(String? globalId) =>
      globalId != null && bigThreeGlobalIds.contains(globalId);

  /// Kulüplerin oluşturulma önceliği: Big 3 → uzman kulüpler.
  static List<GlobalClubTemplate> prioritizedForBranch(String branch) {
    final usable =
        allFixed.where((t) => t.participatesInBranch(branch)).toList();
    usable.sort((a, b) {
      final aDev = a.bigThreeDev ? 0 : 1;
      final bDev = b.bigThreeDev ? 0 : 1;
      if (aDev != bDev) return aDev.compareTo(bDev);
      final asp = a.isSpecialistOneBranch ? 0 : 1;
      final bsp = b.isSpecialistOneBranch ? 0 : 1;
      if (asp != bsp) return asp.compareTo(bsp);
      return a.globalId.compareTo(b.globalId);
    });
    return UnmodifiableListView(usable);
  }
}
