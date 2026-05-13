import 'dart:math';

/// Ligdeki bot kulüplerin kalite kutusu (Süper Lig dağılımı buna göre kurulur).
enum TeamType { elite, contender, stable, underdog }

/// Soyut finansal güç seviyesi (legacy / eşleşme görünümü için).
enum BudgetClass {
  supreme,
  megabudget,
  upper,
  middle,
  lower,
  minimal,
}

extension TeamTypeX on TeamType {
  String get label => switch (this) {
        TeamType.elite => 'Elite',
        TeamType.contender => 'İddialı',
        TeamType.stable => 'Stabil',
        TeamType.underdog => 'Dışlanan',
      };
}

extension BudgetClassX on BudgetClass {
  String get label => switch (this) {
        BudgetClass.supreme => 'Çok Yüksek',
        BudgetClass.megabudget => 'Mega bütçe',
        BudgetClass.upper => 'Üst düzey',
        BudgetClass.middle => 'Orta',
        BudgetClass.lower => 'Sınırlı',
        BudgetClass.minimal => 'Minimal',
      };
}

abstract final class BotTeamFactory {
  /// Ekonomi kademesi (1–5) bu değerin altındayken **elite** bot tipi yasak
  /// (`contender` ile tavanlanır). Dev (Big3) şablonları ayrıca yalnızca
  /// bu kademe ve üzeri liglerde tabloya eklenir.
  static const int eliteMinEconomyTier = 4;

  static TeamType clampTeamTypeToEconomyTier(
    TeamType type,
    int economyTier1to5,
  ) {
    final tier = economyTier1to5.clamp(1, 5);
    if (tier < eliteMinEconomyTier && type == TeamType.elite) {
      return TeamType.contender;
    }
    return type;
  }

  /// Rastgele dağılımdan sonra güvenlik filtresi: alt kademede Elite kalmaz.
  static List<TeamType> finalizeBotAllocationList(
    List<TeamType> types,
    int economyTier1to5,
  ) {
    final tier = economyTier1to5.clamp(1, 5);
    if (tier >= eliteMinEconomyTier) return types;
    return types
        .map((e) => e == TeamType.elite ? TeamType.contender : e)
        .toList();
  }

  static BudgetClass budgetClassFor(
    TeamType type, {
    bool bigThreeDev = false,
  }) {
    if (bigThreeDev) return BudgetClass.supreme;
    return budgetFor(type);
  }

  static BudgetClass budgetFor(TeamType type) => switch (type) {
        TeamType.elite => BudgetClass.megabudget,
        TeamType.contender => BudgetClass.upper,
        TeamType.stable => BudgetClass.middle,
        TeamType.underdog => BudgetClass.lower,
      };

  /// Rastgele taban güç (0–100) — takım tipine göre aralık.
  static int rollBasePower(Random rng, TeamType type) => switch (type) {
        TeamType.elite => 72 + rng.nextInt(21), // 72–92
        TeamType.contender => 54 + rng.nextInt(19), // 54–72
        TeamType.stable => 42 + rng.nextInt(17), // 42–58
        TeamType.underdog => 26 + rng.nextInt(17), // 26–42
      };

  /// Şampiyonluk geçmişi: sadece Elite için 5–20; diğerleri daha düşük.
  static int rollTitles(Random rng, TeamType type) {
    switch (type) {
      case TeamType.elite:
        return 5 + rng.nextInt(16);
      case TeamType.contender:
        return rng.nextInt(4); // 0–3
      case TeamType.stable:
        return rng.nextBool() ? rng.nextInt(3) : 0; // 0–2
      case TeamType.underdog:
        return rng.nextInt(2); // 0–1
    }
  }

  /// Seviye [leagueEconomyTier] ekonomi kademesine göre dağılım.
  ///
  /// 1–3: **Elite yok** (GlobalClubCatalog / Big3 şablonları ayrı). 4+: Elite.
  /// 5 = en yoğun Elite (Süper Lig benzeri).
  static List<(TeamType type, double weight)> _tierRecipe(int tier) {
    final t = tier.clamp(1, 5);
    if (t <= 3) {
      return const [
        (TeamType.contender, 5),
        (TeamType.stable, 9),
        (TeamType.underdog, 10),
      ];
    }
    if (t == 4) {
      return const [
        (TeamType.elite, 2),
        (TeamType.contender, 6),
        (TeamType.stable, 7),
        (TeamType.underdog, 5),
      ];
    }
    return const [
      (TeamType.elite, 4),
      (TeamType.contender, 6),
      (TeamType.stable, 6),
      (TeamType.underdog, 4),
    ];
  }

  /// Hedef kutulara göre `botCount` kadar tip listesi.
  ///
  /// [leagueEconomyTier]: ekonomi kademesi 1–5 (aynı zamanda mantıksal lig seviyesi).
  /// [leagueLevel] verilirse bu kullanılır ([leagueEconomyTier] ile aynı ölçek).
  static List<TeamType> allocateTypes({
    required int botCount,
    required Random rng,
    required int leagueEconomyTier,
    int? leagueLevel,
  }) {
    if (botCount <= 0) return [];

    final tier = (leagueLevel ?? leagueEconomyTier).clamp(1, 5);
    final recipe = _tierRecipe(tier);

    final totalW = recipe.fold<double>(0, (s, e) => s + e.$2);
    final raw = <TeamType, int>{};
    var assigned = 0;
    for (var i = 0; i < recipe.length; i++) {
      final (tp, w) = recipe[i];
      final isLast = i == recipe.length - 1;
      final n = isLast
          ? (botCount - assigned)
          : max(0, (botCount * w / totalW).round());
      raw[tp] = n;
      assigned += n;
    }

    var diff = botCount - assigned;
    if (diff != 0) {
      final bumpOrder = tier <= 3
          ? [
              TeamType.underdog,
              TeamType.stable,
              TeamType.contender,
            ]
          : [
              TeamType.underdog,
              TeamType.stable,
              TeamType.contender,
              TeamType.elite,
            ];
      var k = 0;
      while (diff != 0 && k < 100) {
        final target = bumpOrder[k % bumpOrder.length];
        if (diff > 0) {
          raw[target] = (raw[target] ?? 0) + 1;
          diff--;
        } else if ((raw[target] ?? 0) > 0) {
          raw[target] = raw[target]! - 1;
          diff++;
        }
        k++;
      }
    }

    final out = <TeamType>[];
    for (final e in recipe) {
      final n = raw[e.$1] ?? 0;
      for (var j = 0; j < n; j++) {
        out.add(e.$1);
      }
    }

    final fillLow = tier <= 3 ? TeamType.underdog : TeamType.stable;
    while (out.length < botCount) {
      out.add(fillLow);
    }
    while (out.length > botCount) {
      out.removeLast();
    }

    out.shuffle(rng);
    return finalizeBotAllocationList(out, tier);
  }
}
