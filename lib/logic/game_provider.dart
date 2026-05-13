import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:presidento/models/models.dart';

// ---------------------------------------------------------------------------
// MatchOutcome / WeeklyMatchResult
// ---------------------------------------------------------------------------

enum MatchOutcome { win, draw, loss }

class WeeklyMatchResult {
  final String branch;
  final int points;
  final MatchOutcome outcome;
  /// Bu hafta lig maçı var mı? (Basketbol/Voleybol dönüşümlü haftalar.)
  final bool hadLeagueMatch;
  final int goalsFor;
  final int goalsAgainst;

  const WeeklyMatchResult({
    required this.branch,
    required this.points,
    required this.outcome,
    this.hadLeagueMatch = true,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  String get outcomeLabel => switch (outcome) {
        MatchOutcome.win => 'Galibiyet',
        MatchOutcome.draw => 'Beraberlik',
        MatchOutcome.loss => 'Mağlubiyet',
      };

  /// Skorbord gösterimi (ör. "2 · 1")
  String get scoreLine => '$goalsFor · $goalsAgainst';
}

// ---------------------------------------------------------------------------
// Türkiye Kupası — Kupa Turu
// ---------------------------------------------------------------------------

enum CupRound {
  r1('1. Tur', 20000),
  r2('2. Tur', 50000),
  quarterfinal('Çeyrek Final', 150000),
  semifinal('Yarı Final', 400000),
  cupFinal('Final', 1000000),
  champion('Kupa Şampiyonu', 2500000);

  const CupRound(this.label, this.basePrize);
  final String label;
  final double basePrize;

  CupRound? get next => switch (this) {
        CupRound.r1           => CupRound.r2,
        CupRound.r2           => CupRound.quarterfinal,
        CupRound.quarterfinal => CupRound.semifinal,
        CupRound.semifinal    => CupRound.cupFinal,
        CupRound.cupFinal     => CupRound.champion,
        CupRound.champion     => null,
      };
}

class CupMatchResult {
  final String branch;
  final CupRound round;
  final bool advanced;
  final String opponentLeague;
  final bool opponentWasHigherLeague;
  final double prizeEarned;

  const CupMatchResult({
    required this.branch,
    required this.round,
    required this.advanced,
    required this.opponentLeague,
    required this.opponentWasHigherLeague,
    required this.prizeEarned,
  });
}

// ---------------------------------------------------------------------------
// BranchSeasonResult
// ---------------------------------------------------------------------------

class BranchSeasonResult {
  final String branch;
  final int totalPoints;
  final bool promoted;
  final bool relegated;
  final int tableRank;
  final String newLeagueName;
  final double terminationPenalty;
  final double rankingBonus;
  final String cupProgress;

  const BranchSeasonResult({
    required this.branch,
    required this.totalPoints,
    required this.promoted,
    this.relegated      = false,
    this.tableRank      = 0,
    required this.newLeagueName,
    this.terminationPenalty = 0,
    this.rankingBonus       = 0,
    this.cupProgress        = '—',
  });
}

// ---------------------------------------------------------------------------
// WeeklyEconomySummary
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Branş bazlı haftalık gelir kalemi
// ---------------------------------------------------------------------------
class BranchWeeklyIncome {
  final String branch;
  final double ticketRevenue;
  final double broadcastingRevenue;
  final double matchPrize;
  final double sponsorBonus;
  final double cupPrize;
  final double maintenanceCost;
  final MatchOutcome outcome;

  const BranchWeeklyIncome({
    required this.branch,
    this.ticketRevenue       = 0,
    this.broadcastingRevenue = 0,
    this.matchPrize          = 0,
    this.sponsorBonus        = 0,
    this.cupPrize            = 0,
    this.maintenanceCost     = 0,
    required this.outcome,
  });

  double get totalRevenue =>
      ticketRevenue + broadcastingRevenue + matchPrize + sponsorBonus + cupPrize;
  double get net => totalRevenue - maintenanceCost;
}

// ---------------------------------------------------------------------------
// WeeklyEconomySummary
// ---------------------------------------------------------------------------
class WeeklyEconomySummary {
  final double totalRevenue;
  final double totalCosts;
  final double netChange;
  final double sponsorWinBonus;
  final double cupPrizeTotal;
  final double broadcastingTotal;
  final double matchPrizeTotal;
  final bool hadCupMatch;
  /// Kalem kalem branş gelir detayları (UI için)
  final List<BranchWeeklyIncome> breakdown;

  const WeeklyEconomySummary({
    required this.totalRevenue,
    required this.totalCosts,
    required this.netChange,
    this.sponsorWinBonus    = 0,
    this.cupPrizeTotal      = 0,
    this.broadcastingTotal  = 0,
    this.matchPrizeTotal    = 0,
    this.hadCupMatch        = false,
    this.breakdown          = const [],
  });
}

// ---------------------------------------------------------------------------
// Lig puan durumu (sanal tablo)
// ---------------------------------------------------------------------------

class LeagueStandingEntry {
  LeagueStandingEntry({
    required this.teamName,
    required this.isPlayer,
    this.played = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.points = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.weeklyForm = 0,
    this.basePower = 0,
    this.titlesCount = 0,
    this.teamType,
    this.budgetClass,
    this.globalId,
  });

  String teamName;
  bool isPlayer;
  int played;
  int wins;
  int draws;
  int losses;
  int points;
  int goalsFor;
  int goalsAgainst;

  /// Bu haftalık form (-3…+3); her `advanceWeek` başında yeniden çekilir.
  int weeklyForm;

  /// Kalıcı taban güç (0–100). Botlar için; oyuncu satırında 0.
  int basePower;

  /// Lig şampiyonluğu sayısı (legacy). Oyuncu 0 ile başlar.
  int titlesCount;

  /// Bot kalite kutusu; oyuncu için null.
  TeamType? teamType;

  /// Finansal güç seviyesi; oyuncu için null.
  BudgetClass? budgetClass;

  /// Küresel kimlik (`GlobalClubCatalog`). Rastgele botlar için null.
  String? globalId;

  int get goalDifference => goalsFor - goalsAgainst;

  Map<String, dynamic> toMap() => {
        'teamName': teamName,
        'isPlayer': isPlayer,
        'played': played,
        'wins': wins,
        'draws': draws,
        'losses': losses,
        'points': points,
        'goalsFor': goalsFor,
        'goalsAgainst': goalsAgainst,
        'weeklyForm': weeklyForm,
        'basePower': basePower,
        'titlesCount': titlesCount,
        'teamType': teamType?.name,
        'budgetClass': budgetClass?.name,
        'globalId': globalId,
      };

  factory LeagueStandingEntry.fromMap(Map<String, dynamic> m) {
    TeamType? tt;
    final ts = m['teamType'] as String?;
    if (ts != null) {
      for (final v in TeamType.values) {
        if (v.name == ts) {
          tt = v;
          break;
        }
      }
    }
    BudgetClass? bc;
    final bs = m['budgetClass'] as String?;
    if (bs != null) {
      for (final v in BudgetClass.values) {
        if (v.name == bs) {
          bc = v;
          break;
        }
      }
    }
    return LeagueStandingEntry(
      teamName: m['teamName'] as String,
      isPlayer: m['isPlayer'] as bool? ?? false,
      played: m['played'] as int? ?? 0,
      wins: m['wins'] as int? ?? 0,
      draws: m['draws'] as int? ?? 0,
      losses: m['losses'] as int? ?? 0,
      points: m['points'] as int? ?? 0,
      goalsFor: m['goalsFor'] as int? ?? 0,
      goalsAgainst: m['goalsAgainst'] as int? ?? 0,
      weeklyForm: m['weeklyForm'] as int? ?? 0,
      basePower: m['basePower'] as int? ?? 0,
      titlesCount: m['titlesCount'] as int? ?? 0,
      teamType: tt,
      budgetClass: bc,
      globalId: m['globalId'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Sponsor sistemi
// ---------------------------------------------------------------------------

enum SponsorType { guaranteed, performance, prestige, namingRights }

/// Marka gücü: Elite kulüp itibarı > 70 değilse teklif listesinde yer almaz.
enum SponsorBrandTier { elite, pro, local }

class SponsorOffer {
  final String id;
  final String sponsorName;
  final String branch;
  final SponsorType type;
  final String sector;
  final double upfrontPayment;
  final double winBonus;
  final int reputationBonus;
  final String description;

  /// Sezon sonu min puan şartı. Altına düşülürse ceza kesilir.
  final int? pointTarget;
  /// Ceza: upfrontPayment × penaltyFactor kadar treasury'den düşülür.
  final double penaltyFactor;

  /// Stat isim hakkı sponsoru (çok büyük ödeme, çok sezonlu)
  final bool isNamingRights;
  final int? contractSeasons;

  /// Marka gücü (Elite / Pro / Yerel); yalnızca sezon başı havuzundan üretilir.
  final SponsorBrandTier? brandTier;

  const SponsorOffer({
    required this.id,
    required this.sponsorName,
    required this.branch,
    required this.type,
    this.sector = 'Genel',
    required this.upfrontPayment,
    required this.winBonus,
    this.reputationBonus = 0,
    required this.description,
    this.pointTarget,
    this.penaltyFactor = 0.5,
    this.isNamingRights = false,
    this.contractSeasons,
    this.brandTier,
  });

  String get typeLabel => switch (type) {
        SponsorType.guaranteed   => 'A Tipi · Garanti',
        SponsorType.performance  => 'B Tipi · Performans',
        SponsorType.prestige     => 'C Tipi · Prestij',
        SponsorType.namingRights => 'Stat İsim Hakkı',
      };

  /// Fesih koşulunu açıklayan metin (yoksa null).
  String? get terminationClause => pointTarget == null
      ? null
      : 'Risk Şartı: Sezon sonu ${pointTarget!} puanın altında kalırsan '
        '${_fmtAmt(upfrontPayment * penaltyFactor)} iade etmen gerekir.';

  String? get brandTierLabel => switch (brandTier) {
        SponsorBrandTier.elite => 'Elite',
        SponsorBrandTier.pro => 'Pro',
        SponsorBrandTier.local => 'Yerel',
        null => null,
      };
}

String _fmtAmt(double v) {
  if (v >= 1000000) return '€${(v / 1000000).toStringAsFixed(2)}M';
  if (v >= 1000)    return '€${(v / 1000).toStringAsFixed(0)}K';
  return '€${v.toStringAsFixed(0)}';
}

class ActiveSponsor {
  final SponsorOffer offer;
  int seasonWins;
  int remainingContractSeasons;

  ActiveSponsor({
    required this.offer,
    this.seasonWins = 0,
    int? contractSeasons,
  }) : remainingContractSeasons = contractSeasons ?? 1;

  double get totalBonusEarned => offer.winBonus * seasonWins;
}


// ---------------------------------------------------------------------------
// Yatırım sistemi
// ---------------------------------------------------------------------------

/// 3 yatırım türü: Tesis, Altyapı, Pazarlama.
enum InvestmentType { facility, infrastructure, marketing }

/// Yatırım seviyesi bilgisi (1-5 arası).
class InvestmentTier {
  final int    level;
  final double cost;           // Satın alma maliyeti
  final String effectDescription; // Maksimum verimde etki açıklaması

  const InvestmentTier({
    required this.level,
    required this.cost,
    required this.effectDescription,
  });
}

/// Yatırım kataloğu — 5 seviyeli, maliyet = seviye × 200.000 €.
///
/// Maksimum verim etkileri (Katsayı = 1.0 durumunda):
///   Tesis        → bakım giderini azaltır (L5: -%30)
///   Altyapı      → başarı oranına eklenir (L5: +%15)
///   Pazarlama    → bilet/yayın gelirine çarpan  (L5: ×1.50)
class InvestmentCatalog {
  static const int maxLevel = 5;

  static const List<InvestmentTier> facility = [
    InvestmentTier(level: 1, cost: 200000,  effectDescription: 'Bakım −6%'),
    InvestmentTier(level: 2, cost: 400000,  effectDescription: 'Bakım −12%'),
    InvestmentTier(level: 3, cost: 600000,  effectDescription: 'Bakım −18%'),
    InvestmentTier(level: 4, cost: 800000,  effectDescription: 'Bakım −24%'),
    InvestmentTier(level: 5, cost: 1000000, effectDescription: 'Bakım −30%'),
  ];

  static const List<InvestmentTier> infrastructure = [
    InvestmentTier(level: 1, cost: 200000,  effectDescription: 'Başarı +3%'),
    InvestmentTier(level: 2, cost: 400000,  effectDescription: 'Başarı +6%'),
    InvestmentTier(level: 3, cost: 600000,  effectDescription: 'Başarı +9%'),
    InvestmentTier(level: 4, cost: 800000,  effectDescription: 'Başarı +12%'),
    InvestmentTier(level: 5, cost: 1000000, effectDescription: 'Başarı +15%'),
  ];

  static const List<InvestmentTier> marketing = [
    InvestmentTier(level: 1, cost: 200000,  effectDescription: 'Gelir +10%'),
    InvestmentTier(level: 2, cost: 400000,  effectDescription: 'Gelir +20%'),
    InvestmentTier(level: 3, cost: 600000,  effectDescription: 'Gelir +30%'),
    InvestmentTier(level: 4, cost: 800000,  effectDescription: 'Gelir +40%'),
    InvestmentTier(level: 5, cost: 1000000, effectDescription: 'Gelir +50%'),
  ];

  static List<InvestmentTier> tiersFor(InvestmentType type) => switch (type) {
    InvestmentType.facility       => facility,
    InvestmentType.infrastructure => infrastructure,
    InvestmentType.marketing      => marketing,
  };

  /// Bir sonraki seviyenin verisi (maxLevel'deyse null).
  static InvestmentTier? nextTier(InvestmentType type, int currentLevel) {
    if (currentLevel >= maxLevel) return null;
    final list = tiersFor(type);
    final idx  = list.indexWhere((t) => t.level == currentLevel + 1);
    return idx >= 0 ? list[idx] : null;
  }

  // ── Verimlilik Katsayısı ──────────────────────────────────────────────────

  /// Katsayı = clamp(investmentLevel / leagueLevel, 0.1, 1.0)
  /// leagueLevel 0-indexed; 0 gelirse leagueLevel=1 kabul edilir.
  static double efficiencyFactor(int investmentLevel, int leagueIndex) {
    if (investmentLevel <= 0) return 0.0;
    final liglevel = (leagueIndex + 1).toDouble(); // 0-indexed → 1-indexed
    return (investmentLevel / liglevel).clamp(0.1, 1.0);
  }

  // ── Etki Hesaplamaları (katsayı zaten uygulanmış değer) ──────────────────

  /// Tesis → bakım azaltma oranı (0..0.30 arası).
  static double facilityMaintenanceReduction(int level, int leagueIndex) {
    if (level <= 0) return 0.0;
    final base = level * 0.06;   // L5 → 0.30
    return base * efficiencyFactor(level, leagueIndex);
  }

  /// Altyapı → başarı oranı bonusu (0..0.15 arası).
  static double infrastructureSuccessBonus(int level, int leagueIndex) {
    if (level <= 0) return 0.0;
    final base = level * 0.03;   // L5 → 0.15
    return base * efficiencyFactor(level, leagueIndex);
  }

  /// Pazarlama → gelir çarpan bonusu (0..0.50 arası).
  static double marketingRevenueBonus(int level, int leagueIndex) {
    if (level <= 0) return 0.0;
    final base = level * 0.10;   // L5 → 0.50
    return base * efficiencyFactor(level, leagueIndex);
  }
}

// ---------------------------------------------------------------------------
// CountryData
// ---------------------------------------------------------------------------

class CountryData {
  CountryData._();

  static const String football   = 'Futbol';
  static const String basketball = 'Basketbol';
  static const String volleyball = 'Voleybol';

  static const Map<String, double> multipliers = {
    football:   1.6,
    basketball: 1.3,
    volleyball: 1.1,
  };

  static const double economicPower = 1.0;
  static double multiplierFor(String branch) => multipliers[branch] ?? 1.0;

  static const List<String> turkishCities = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya',
    'Ankara', 'Antalya', 'Ardahan', 'Artvin', 'Aydın', 'Balıkesir', 'Bartın',
    'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur',
    'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır',
    'Düzce', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir',
    'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Iğdır',
    'Isparta', 'İstanbul', 'İzmir', 'Kahramanmaraş', 'Karabük', 'Karaman',
    'Kars', 'Kastamonu', 'Kayseri', 'Kilis', 'Kırıkkale', 'Kırklareli',
    'Kırşehir', 'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa',
    'Mardin', 'Mersin', 'Muğla', 'Muş', 'Nevşehir', 'Niğde', 'Ordu',
    'Osmaniye', 'Rize', 'Sakarya', 'Samsun', 'Şanlıurfa', 'Siirt', 'Sinop',
    'Şırnak', 'Sivas', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Uşak',
    'Van', 'Yalova', 'Yozgat', 'Zonguldak',
  ];
}

// ---------------------------------------------------------------------------
// BranchLeagueData
// ---------------------------------------------------------------------------

class BranchLeagueData {
  BranchLeagueData._();

  /// Denge tablosu — her kademe için takım sayısı ve düşme/çıkma.
  /// Futbol: BAL → Süper Lig
  static const List<int> _footballTeamCounts      = [14, 16, 18, 20, 20];
  /// Bu ligden üst lige çıkan takım sayısı (en alt lig bile en üste doğru sıra).
  static const List<int> _footballPromoteUpwards  = [2, 3, 3, 4, 0];
  /// Bu ligden alt lige düşen takım sayısı.
  static const List<int> _footballRelegateDownwards = [0, 2, 3, 3, 4];

  static const List<int> _basketTeamCounts = [10, 18, 16];
  static const List<int> _basketPromoteUp  = [2, 2, 0];
  static const List<int> _basketRelegateDn = [0, 2, 2];

  static const List<int> _volleyTeamCounts = [11, 14, 14];
  static const List<int> _volleyPromoteUp  = [2, 2, 0];
  static const List<int> _volleyRelegateDn = [0, 2, 2];

  static const Map<String, List<String>> leagues = {
    CountryData.football: [
      'BAL',
      '3. Lig',
      '2. Lig',
      '1. Lig',
      'Süper Lig',
    ],
    CountryData.basketball: [
      'TB2L',
      'TBL',
      'BSL',
    ],
    CountryData.volleyball: [
      '2. Lig',
      '1. Lig',
      'Efeler Ligi',
    ],
  };

  /// Tüm kulüpler 38 haftada sezon sonu görür.
  static const int seasonWeeksTotal = 38;

  /// Bu branşta sezon içinde oynanan lig maçı hafta sayısı.
  static int leagueMatchWeeksInSeason(String branch) {
    if (branch == CountryData.football) return 38;
    return 19; // Basket / Voley dönüşümlü Haftalar
  }

  /// Küresel takvim: Futbol her hafta maçlar; Basketbol tek sayılı haftalarda,
  /// Voleybol çift sayılı haftalarda (38 hafta içinde dengeli yayılım).
  static bool hasLeagueMatchWeek(String branch, int currentWeekOneBased) {
    if (currentWeekOneBased < 1 || currentWeekOneBased > seasonWeeksTotal) {
      return false;
    }
    if (branch == CountryData.football) return true;
    if (branch == CountryData.basketball) {
      return currentWeekOneBased.isOdd; // 1,3,...,37 → 19 hafta
    }
    if (branch == CountryData.volleyball) {
      return currentWeekOneBased.isEven; // 2,4,...,38 → 19 hafta
    }
    return true;
  }

  /// Ligde takım sayısı (sıralama / tablo oluşturmak için).
  static int leagueTeamCount(String branch, int levelIndex) {
    final i = levelIndex.clamp(0, leagueCount(branch) - 1);
    switch (branch) {
      case CountryData.football:
        return _footballTeamCounts[i];
      case CountryData.basketball:
        return _basketTeamCounts[i];
      case CountryData.volleyball:
        return _volleyTeamCounts[i];
      default:
        return 14;
    }
  }

  /// Bu lig kademesinden üst sıraya çıkacak ilk N sıra küme çıkarılır (oyuncu için).
  static int promoteSlots(String branch, int levelIndex) {
    if (isTopLeague(branch, levelIndex)) return 0;
    final i = levelIndex.clamp(0, leagueCount(branch) - 1);
    return switch (branch) {
      CountryData.football => _footballPromoteUpwards[i],
      CountryData.basketball => _basketPromoteUp[i],
      CountryData.volleyball => _volleyPromoteUp[i],
      _ => 0,
    };
  }

  /// Bu ligden alt lige düşecek takım sayısı (sıralamanın dibinden sayılır).
  static int relegateSlots(String branch, int levelIndex) {
    if (isBottomLeague(branch, levelIndex)) return 0;
    final i = levelIndex.clamp(0, leagueCount(branch) - 1);
    return switch (branch) {
      CountryData.football => _footballRelegateDownwards[i],
      CountryData.basketball => _basketRelegateDn[i],
      CountryData.volleyball => _volleyRelegateDn[i],
      _ => 0,
    };
  }

  static bool isBottomLeague(String branch, int levelIndex) =>
      levelIndex <= 0;

  /// Şampiyonluk (Aggressive) bütçe hedefleri — her lig seviyesi için önerilen €.
  static const Map<String, List<double>> championshipBudgets = {
    CountryData.football:   [150000, 600000, 2500000, 10000000, 60000000],
    CountryData.basketball: [150000, 1000000, 15000000],
    CountryData.volleyball: [60000, 400000, 6000000],
  };

  /// O branşın mevcut ligindeki şampiyonluk bütçesi.
  static double aggressiveBudget(String branch, int levelIndex) {
    final list = championshipBudgets[branch] ?? const [150000.0];
    return list[levelIndex.clamp(0, list.length - 1)].toDouble();
  }

  // ── Haftalık gelir ekonomisi (lig kademesi 1–5 referansları) ────────────────
  //
  // Futbol ölçeği: L1=BAL … L5=Süper Lig. Basket / voley: taban kademeye eşlenir.
  /// Aylığa yakın ekonomi yüzölçeği için 1.0 … 5.0 (küsurat ara değer = interpolasyon).
  static double economyTier(String branch, int levelIndex) {
    final raw = BranchLeagueData.leagueCount(branch);
    final safe = raw < 2 ? levelIndex.clamp(0, 10) : levelIndex.clamp(0, raw - 1);

    switch (branch) {
      case CountryData.football:
        return (safe + 1).toDouble().clamp(1.0, 5.0);
      case CountryData.basketball:
        switch (safe) {
          case 0:
            return 1.0; // TB2L ≈ Seviye 1
          case 1:
            return 3.0; // TBL ≈ Seviye 3
          default:
            return 5.0; // BSL ≈ Süper Lig
        }
      case CountryData.volleyball:
        switch (safe) {
          case 0:
            return 2.0; // 2. Lig
          case 1:
            return 4.0; // 1. Lig
          default:
            return 5.0; // Efeler ≈ Süper Lig
        }
      default:
        return (safe + 1).toDouble().clamp(1.0, 5.0);
    }
  }

  /// Tam sayı ekonomi derecesi (bot tipi filtresi ve UI için).
  static int economyTierInt(String branch, int levelIndex) =>
      economyTier(branch, levelIndex).round().clamp(1, 5);

  /// Referans bilet haftalık baz (€) — kademeler 1..5 doğrusal ara değer.
  static const List<double> _economyTicketAnchorsEuro = [
    500, 2500, 10000, 40000, 150000,
  ];

  /// Referans yayın haftalık baz (€) — L1’de 0 €.
  static const List<double> _economyBroadcastAnchorsEuro = [
    0, 500, 5000, 25000, 200000,
  ];

  /// Sponsor peşinat ölçeği (€) — alt lig düşük, üst lig yüksek.
  static const List<double> _economySponsorAnchorsEuro = [
    8000, 40000, 160000, 650000, 2800000,
  ];

  static double _lerpEconomyAnchors(List<double> anchors, double tier1to5) {
    assert(anchors.length >= 2);
    final t = tier1to5.clamp(1.0, anchors.length.toDouble());
    final idx = t - 1.0;
    if (idx >= anchors.length - 1) return anchors.last;
    final lo = idx.floor().clamp(0, anchors.length - 2);
    final frac = idx - lo;
    final a = anchors[lo];
    final b = anchors[lo + 1];
    return a + frac * (b - a);
  }

  /// Üst uçların kademeli büyümesi için log doğrusal bilet (~üstel büyüme oranında).
  static double _tierTicketLogInterpolated(double tier1to5) {
    final tMin = _economyTicketAnchorsEuro.first;
    final tMax = _economyTicketAnchorsEuro.last;
    final ratio = tMax / tMin;
    final u = ((tier1to5.clamp(1.0, 5.0) - 1.0) / 4.0).clamp(0.0, 1.0);
    return tMin * pow(ratio, u);
  }

  /// Branşa göre hafif gelir düzeltmesi (kök alınmış — fazla süperlinearity engellenir).
  static double _branchRevenueTone(String branch) {
    final m = sqrt(CountryData.multiplierFor(branch));
    return m.clamp(0.85, 1.45);
  }

  /// Haftalık sponsor teklifi ölçütü için lig baz nakit (~peşinat seviye çarpanı).
  static double sponsorOfferBaseEuros(String branch, int levelIndex) {
    return _lerpEconomyAnchors(
      _economySponsorAnchorsEuro,
      economyTier(branch, levelIndex),
    );
  }

  static const Map<String, double> budgetImpactMultipliers = {
    CountryData.football:   1.0,
    CountryData.basketball: 2.5,
    CountryData.volleyball: 4.0,
  };

  static const double baseDifficulty = 500000;

  static int leagueCount(String branch) => leagues[branch]?.length ?? 1;

  static double difficultyAt(String branch, int levelIndex) {
    final clamped = levelIndex.clamp(0, leagueCount(branch) - 1);
    return baseDifficulty * pow(2, clamped);
  }

  /// SuccessRate = (budget × impactMultiplier / difficulty) × fanBonus × infraBonus
  static double calcSuccessRate({
    required String branch,
    required double budget,
    required int levelIndex,
    int fanInterest = 50,
    int infrastructureLevel = 0,
  }) {
    final impactMultiplier = budgetImpactMultipliers[branch] ?? 1.0;
    final difficulty = difficultyAt(branch, levelIndex);
    final fanBonus = (0.8 + fanInterest * 0.004).clamp(0.5, 1.5);
    final infraBonus = 1.0 + infrastructureLevel * 0.05;
    return (budget * impactMultiplier / difficulty * fanBonus * infraBonus)
        .clamp(0.0, 1.0);
  }

  /// Bilet haftalık gelir (€): lig ekonomi kademesi + taraftar + isteğe bağlı pazarlama.
  /// Tam kademe değerleri tablo ile hizalı; ara kademeler üstel log + doğrusal ortalama.
  static double ticketRevenue(
    String branch,
    int fanInterest,
    int levelIndex, {
    int marketingLevel = 0,
  }) {
    final tier = economyTier(branch, levelIndex);
    final linear =
        _lerpEconomyAnchors(_economyTicketAnchorsEuro, tier);
    final expo = _tierTicketLogInterpolated(tier);
    final baseEuro = (linear + expo) * 0.5;
    final fanMod = (0.72 + fanInterest * 0.0068).clamp(0.62, 1.38);
    final mktBonus =
        marketingLevel <= 0 ? 1.0 : (1.0 + marketingLevel * 0.25);
    return baseEuro * _branchRevenueTone(branch) * fanMod * mktBonus;
  }

  static String leagueName(String branch, int levelIndex) {
    final list = leagues[branch];
    if (list == null || list.isEmpty) return '—';
    return list[levelIndex.clamp(0, list.length - 1)];
  }

  static bool isTopLeague(String branch, int levelIndex) =>
      levelIndex >= leagueCount(branch) - 1;

  // ── Dinamik Ödül Sistemi ───────────────────────────────────────────────────

  /// Galibiyet primleri (€): BAL → Süper Lig (5 seviye futbol hizalı).
  static const List<double> _footballWinPrizes = [
    5000, 60000, 150000, 300000, 500000,
  ];
  static const List<double> _footballDrawPrizes = [
    2000, 20000, 50000, 100000, 175000,
  ];

  /// Haftalık bakım gideri (budget yüzdesi). Futbol 5 seviye hizalı.
  static const List<double> _maintenancePct = [
    0.010, 0.015, 0.020, 0.028, 0.038,
  ];

  /// Galibiyet/beraberlik maç primi.
  static double matchPrize(String branch, int levelIndex, MatchOutcome outcome) {
    if (outcome == MatchOutcome.loss) return 0;
    final lvl     = levelIndex.clamp(0, leagueCount(branch) - 1);
    final impactM = budgetImpactMultipliers[branch] ?? 1.0;
    // Futbol çarpan 1.0; diğerleri ters orantılı (biraz daha küçük ödüller)
    final branchScale = 1.0 / impactM;
    final winBase  = _footballWinPrizes[lvl.clamp(0, _footballWinPrizes.length - 1)];
    final drawBase = _footballDrawPrizes[lvl.clamp(0, _footballDrawPrizes.length - 1)];
    final base = outcome == MatchOutcome.win ? winBase : drawBase;
    return base * branchScale;
  }

  /// Haftalık yayın geliri (€) — lig ekonomi kademesine göre (L1’de ~0).
  static double broadcastingRevenue(String branch, int levelIndex) {
    final tier = economyTier(branch, levelIndex);
    final base = _lerpEconomyAnchors(
      _economyBroadcastAnchorsEuro,
      tier,
    ).clamp(0.0, double.infinity);
    return base * _branchRevenueTone(branch);
  }

  /// Haftalık bakım gideri — lig seviyesine göre artan yüzde.
  static double maintenanceCost(String branch, double budget, int levelIndex) {
    final lvl = levelIndex.clamp(0, _maintenancePct.length - 1);
    return budget * _maintenancePct[lvl];
  }

  /// Sezon sonu sıralama ödülleri (€) — futbol 5 seviye hizalı.
  static const List<double> _rankingPrizes1st = [
    8000, 120000, 350000, 800000, 2000000,
  ];
  static const List<double> _rankingPrizes2_5 = [
    3000, 45000, 130000, 300000, 750000,
  ];

  /// Sezon sonu sıralama ödülü: tablo sırasına göre (maç sayısı branşlar arası değiştiği için).
  static double rankingBonusByRank(String branch, int levelIndex, int tableRank) {
    if (tableRank < 1) return 0;
    final lvl = levelIndex.clamp(0, leagueCount(branch) - 1);
    final impactM = budgetImpactMultipliers[branch] ?? 1.0;
    final branchScale = 1.0 / impactM;
    final base1st =
        _rankingPrizes1st[lvl.clamp(0, _rankingPrizes1st.length - 1)];
    final base2_5 =
        _rankingPrizes2_5[lvl.clamp(0, _rankingPrizes2_5.length - 1)];
    if (tableRank == 1) return base1st * branchScale;
    if (tableRank <= 5) return base2_5 * branchScale;
    return 0;
  }
}

// ---------------------------------------------------------------------------
// GameProvider
// ---------------------------------------------------------------------------

class GameProvider extends ChangeNotifier {
  Club?      _currentClub;
  President? _currentPresident;
  final _rng = Random();

  /// Yeni kayıtta kulüp kasası ve kurulumdaki dağıtılabilir toplam üst sınırı (€).
  static const double initialTreasuryEuros = 500000.0;

  static const int _seasonLength = BranchLeagueData.seasonWeeksTotal;

  // --- Lig / Puan ---
  final Map<String, int> _branchLeagueIndices = {
    CountryData.football: 0, CountryData.basketball: 0, CountryData.volleyball: 0,
  };
  int _currentWeek = 1;
  final Map<String, int> _branchPoints = {
    CountryData.football: 0, CountryData.basketball: 0, CountryData.volleyball: 0,
  };

  // --- Sezon sonuçları ---
  List<BranchSeasonResult>? _lastSeasonResults;
  List<WeeklyMatchResult>   _lastWeekResults = [];
  WeeklyEconomySummary?     _lastEconomySummary;

  // --- Sponsorlar ---
  final Map<String, ActiveSponsor?>          _activeSponsors      = {};
  final Map<String, List<SponsorOffer>>      _pendingSponsorOffers = {};
  bool _needsSponsorSelection = false;

  /// Stat isim hakkı sözleşmesi kalan sezon sayısı (branch → kalan sezon).
  final Map<String, int> _namingRightsSeasons = {};
  int _seasonNumber = 1;
  /// Oynanmakta olan veya yeni başlayan sezonun takvim yılı (UI / sezon geçişi).
  int _calendarYear = museumCalendarBaseYear;

  // --- Başkanlık kararları / moral ---
  RandomEvent? _pendingRandomPresidentEvent;
  int _weeksAccumulatedPresident = 0;
  int _presidentNextGapWeeks = 3;
  final Map<String, int> _branchMoraleNextFixture = {};

  // --- Türkiye Kupası ---
  /// Kupa maçları bu haftalar oynanır (sezon içi). Haftalar 1-indexed.
  static const Map<int, CupRound> _cupWeekMap = {
    8: CupRound.r1,
    16: CupRound.r2,
    24: CupRound.quarterfinal,
    32: CupRound.semifinal,
    38: CupRound.cupFinal,
  };
  /// Branş başına mevcut kupa turu (null = elenmiş, champion = şampiyon).
  final Map<String, CupRound?> _branchCupRound = {
    CountryData.football: CupRound.r1,
    CountryData.basketball: CupRound.r1,
    CountryData.volleyball: CupRound.r1,
  };
  /// Branş başına ulaşılan en iyi kupa turu (sezon sonu raporu için).
  final Map<String, CupRound?> _branchCupFarthest = {};
  /// O haftanın kupa maç sonuçları.
  List<CupMatchResult> _lastCupResults = [];

  // --- Yatırımlar ---
  final Map<String, int> _facilityLevels = {
    CountryData.football: 0, CountryData.basketball: 0, CountryData.volleyball: 0,
  };
  final Map<String, int> _infrastructureLevels = {
    CountryData.football: 0, CountryData.basketball: 0, CountryData.volleyball: 0,
  };
  final Map<String, int> _marketingLevels = {
    CountryData.football: 0, CountryData.basketball: 0, CountryData.volleyball: 0,
  };

  /// Branş bazlı lig tablosu (oyuncu + sanal takımlar).
  final Map<String, List<LeagueStandingEntry>> _leagueStandings = {};

  /// Haftanın lig eşleşmeleri (oyuncu–rakip ile aynı fikstür `_simulateLeagueRound` için).
  final Map<String, List<(LeagueStandingEntry, LeagueStandingEntry)>>
      _weekLeaguePairings = {};

  /// Sezon için önceden üretilmiş Berger fikstürü (isim çiftleri).
  final Map<String, List<List<(String, String)>>> _seasonFixturePlans = {};
  /// `hasLeagueMatchWeek` true olan takvim haftaları için önbellek.
  final Map<String, List<int>> _leagueCalendarWeeksMemo = {};
  /// Oynanmış lig karşılaşmaları arşivi.
  final List<MatchResult> _matchHistory = [];
  static const int _matchArchiveSoftCap = 600;

  /// Müze vitrini — oyuncunun branş bazlı lig şampiyonlukları.
  final List<Trophy> _trophyRoom = [];

  /// Şampiyonluk yılı etiketi: 1. sezon = bu yıl, her yeni sezon +1.
  static const int museumCalendarBaseYear = 2026;

  static int museumYearForEndedSeason(int seasonNumber) =>
      museumCalendarBaseYear + seasonNumber - 1;

  /// Tesis isim hakkı (S5) tek seferlik satıldı mı?
  final Map<String, bool> _facilityNamingSold = {
    CountryData.football: false,
    CountryData.basketball: false,
    CountryData.volleyball: false,
  };

  /// Satılan akademi / tesis adı (ör. Trendyol Akademi).
  final Map<String, String?> _facilityNamingLabel = {
    CountryData.football: null,
    CountryData.basketball: null,
    CountryData.volleyball: null,
  };

  /// Tabloda kullanılan sanal kulüp adları.
  static const List<String> _nationalBotClubNames = [
    'İstanbul Gücü', 'Ankara FK', 'İzmir City', 'Bursa Spor', 'Antalya FK',
    'Adanaspor', 'Trabzon SK', 'Konya FK', 'Gaziantep City', 'Eskişehir SK',
    'Samsun SK', 'Malatya FK', 'Hatay Gücü', 'Mersin City', 'Kayseri SK',
    'Diyarbakır FK', 'Sakarya SK', 'Kocaelispor', 'Denizli Gücü', 'Balıkesir FK',
    'Erzurum SK', 'Rize FK', 'Giresun FK', 'Şanlıurfa SK', 'Alanya SK',
    'Çanakkale FK', 'Bodrum City', 'Fethiye FK', 'Kuşadası SK', 'Nevşehir FK',
    'Pamukkale SK', 'Ege FK', 'Marmaris SK', 'Fatsa Gücü', 'Ordu FK',
  ];

  // ── Getters ────────────────────────────────────────────────────────────────

  Club?      get currentClub      => _currentClub;
  President? get currentPresident => _currentPresident;

  bool get isGameStarted  => _currentClub != null && _currentPresident != null;
  int  get currentWeek    => _currentWeek;
  int  get seasonLength   => _seasonLength;
  bool get isSeasonOver   => _currentWeek > _seasonLength;

  List<BranchSeasonResult>? get lastSeasonResults  => _lastSeasonResults;
  List<WeeklyMatchResult>   get lastWeekResults    => _lastWeekResults;
  WeeklyEconomySummary?     get lastEconomySummary => _lastEconomySummary;

  bool get needsSponsorSelection => _needsSponsorSelection;
  int  get seasonNumber          => _seasonNumber;
  /// Örn. 2026 — yeni sezonda artar (`startNewSeason`).
  int  get calendarYear          => _calendarYear;

  List<Trophy> get trophyRoom => List<Trophy>.unmodifiable(_trophyRoom);

  /// Müze rozetleri: her kupa nakit bazlı sponsorlık tekliflerine +%5.
  double get sponsorMuseumCashMultiplier =>
      1.0 + _trophyRoom.length * 0.05;

  /// Sadece aktif naming-rights sözleşmesi OLMAYAN branşlar sponsor seçmek zorunda.
  List<String> get branchesNeedingSponsor => [
    CountryData.football, CountryData.basketball, CountryData.volleyball,
  ].where((b) => _namingRightsSeasons[b] == null || _namingRightsSeasons[b]! <= 0).toList();

  bool get allSponsorsSelected =>
      branchesNeedingSponsor.every((b) => _activeSponsors[b] != null);

  Map<String, List<SponsorOffer>> get sponsorOffersForSeason =>
      Map.unmodifiable(_pendingSponsorOffers);

  /// Stat isim hakkı kalan sezon sayısını döner (varsa).
  int namingRightsRemaining(String branch) => _namingRightsSeasons[branch] ?? 0;

  int branchPoints(String branch)          => _branchPoints[branch]          ?? 0;
  int branchLeagueIndex(String branch)     => _branchLeagueIndices[branch]   ?? 0;
  int facilityLevel(String branch)         => _facilityLevels[branch]        ?? 0;
  int infrastructureLevel(String branch)   => _infrastructureLevels[branch]  ?? 0;
  int marketingLevel(String branch)        => _marketingLevels[branch]       ?? 0;

  /// Bu branştaki sıralama tablosu (puana göre azalan sıralı kopya).
  List<LeagueStandingEntry> standingsForBranch(String branch) {
    final raw = _leagueStandings[branch];
    if (raw == null || raw.isEmpty) return [];
    final list = [...raw];
    list.sort((a, b) {
      final pc = b.points.compareTo(a.points);
      if (pc != 0) return pc;
      final gd = b.goalDifference.compareTo(a.goalDifference);
      if (gd != 0) return gd;
      final gf = b.goalsFor.compareTo(a.goalsFor);
      if (gf != 0) return gf;
      return a.teamName.compareTo(b.teamName);
    });
    return list;
  }

  String? facilityAcademyLabel(String branch) =>
      _facilityNamingLabel[branch];

  bool facilityNamingSold(String branch) =>
      _facilityNamingSold[branch] ?? false;

  /// S5 tesis ve isim hakkı henüz satılmadıysa kullanıcıya teklif gösterilir.
  bool canOfferFacilityNamingSale(String branch) =>
      facilityLevel(branch) >= InvestmentCatalog.maxLevel &&
      !facilityNamingSold(branch);

  /// Tek seferlik büyük nakit; başarıyla ödenen tutarı döner (aksi halde null).
  double? sellFacilityNamingRights(String branch) {
    final club = _currentClub;
    if (club == null || !canOfferFacilityNamingSale(branch)) return null;
    final levelIdx = _branchLeagueIndices[branch] ?? 0;

    final payment =
        2500000.0 + levelIdx * 750000.0 + _rng.nextInt(250000);

    const academyBrands = [
      'Trendyol',
      'Getir',
      'Yemeksepeti',
      'Turkcell',
      'Türk Hava Yolları',
      'Ziraat Bankası',
    ];
    final brand = academyBrands[_rng.nextInt(academyBrands.length)];
    final label = '$brand Arena';

    _facilityNamingSold[branch] = true;
    _facilityNamingLabel[branch] = label;
    _currentClub = club.copyWith(
      treasury: club.treasury + payment,
      reputation: (club.reputation + 4).clamp(0, 100),
    );

    notifyListeners();
    saveGame();
    return payment;
  }

  /// Verimlilik katsayısı: yatırım etkilerinin gerçek verimini gösterir.
  double investmentEfficiency(InvestmentType type, String branch) {
    final lvl = switch (type) {
      InvestmentType.facility       => _facilityLevels[branch] ?? 0,
      InvestmentType.infrastructure => _infrastructureLevels[branch] ?? 0,
      InvestmentType.marketing      => _marketingLevels[branch] ?? 0,
    };
    final liglevel = _branchLeagueIndices[branch] ?? 0;
    return InvestmentCatalog.efficiencyFactor(lvl, liglevel);
  }
  ActiveSponsor? activeSponsor(String branch) => _activeSponsors[branch];

  /// Bu hafta kupa maçı oynanacak mı?
  bool get isCurrentWeekCupWeek => _cupWeekMap.containsKey(_currentWeek);

  /// Branş hâlâ kupada mı?
  bool isBranchInCup(String branch) {
    final r = _branchCupRound[branch];
    return r != null && r != CupRound.champion;
  }

  /// Branşın mevcut kupa turu.
  CupRound? branchCupRound(String branch) => _branchCupRound[branch];

  /// O haftanın kupa sonuçları.
  List<CupMatchResult> get lastCupResults => _lastCupResults;

  String branchLeagueName(String branch) =>
      BranchLeagueData.leagueName(branch, branchLeagueIndex(branch));

  String get currentLeagueLevelLabel => branchLeagueName(CountryData.football);

  RandomEvent? get pendingPresidentEvent => _pendingRandomPresidentEvent;
  RandomEvent? get pendingChoiceEvent =>
      pendingPresidentEvent; // geriye uyum

  List<MatchResult> get matchHistory => List.unmodifiable(_matchHistory);

  /// Berger fikstüründen düz liste (UI sekme için).
  List<MatchSchedule> get seasonSchedule {
    final club = _currentClub;
    if (club == null) return const [];
    final nm = club.name.trim();
    final xs = <MatchSchedule>[];
    for (final branch in [
      CountryData.football,
      CountryData.basketball,
      CountryData.volleyball,
    ]) {
      final plan = _seasonFixturePlans[branch];
      final weeks = _leagueCalendarWeeksFor(branch);
      if (plan == null || weeks.isEmpty) continue;
      final maxR = min(plan.length, weeks.length);
      for (var ri = 0; ri < maxR; ri++) {
        final cw = weeks[ri];
        for (final (h, a) in plan[ri]) {
          xs.add(MatchSchedule(
            branch: branch,
            calendarWeek: cw,
            leagueRoundIndex: ri + 1,
            homeTeam: h,
            awayTeam: a,
            involvesPlayerClub: nm == h.trim() || nm == a.trim(),
          ));
        }
      }
    }
    xs.sort((a, b) {
      final c = a.calendarWeek.compareTo(b.calendarWeek);
      if (c != 0) return c;
      return a.branch.compareTo(b.branch);
    });
    return xs;
  }

  /// Yeni oyunda her branş için sanal takımlarla tabloyu oluşturur.
  void _initLeagueStandingsTables() {
    final club = _currentClub;
    if (club == null) return;
    for (final branch in [
      CountryData.football, CountryData.basketball, CountryData.volleyball,
    ]) {
      _leagueStandings[branch] =
          _buildStandingsTableForBranch(club.name, club.city, branch);
    }
  }

  void _finalizeBigThreeBudget(LeagueStandingEntry e, String branch) {
    final li = _branchLeagueIndices[branch] ?? 0;
    final econ = BranchLeagueData.economyTierInt(branch, li);
    if (!GlobalClubCatalog.isBigThreeFranchise(e.globalId)) return;
    if (econ >= BotTeamFactory.eliteMinEconomyTier) {
      e.budgetClass = BudgetClass.supreme;
    }
  }

  /// Bu branştaki küresel kulüp isimleri + oyuncu adı — doldurucu havuzdan çıkarılır.
  Set<String> _reservedBotNamesForBranch(String branch, String clubName) {
    final s = <String>{clubName.trim()};
    for (final t in GlobalClubCatalog.allFixed) {
      final spec = t.specForBranch(branch);
      if (spec != null) {
        s.add(spec.displayName.trim());
      }
    }
    return s;
  }

  List<LeagueStandingEntry> _buildStandingsTableForBranch(
      String clubName, String city, String branch) {
    final leagueIdx = _branchLeagueIndices[branch] ?? 0;
    final n =
        BranchLeagueData.leagueTeamCount(branch, leagueIdx).clamp(2, 64);
    final reserved = _reservedBotNamesForBranch(branch, clubName);

    final globalTemplates =
        GlobalClubCatalog.prioritizedForBranch(branch);
    final econTier = BranchLeagueData.economyTierInt(branch, leagueIdx);
    final botEntries = <LeagueStandingEntry>[];

    for (final tmpl in globalTemplates) {
      if (botEntries.length >= n - 1) break;
      final spec = tmpl.specForBranch(branch);
      if (spec == null) continue;
      if (spec.displayName.trim() == clubName.trim()) continue;

      if (tmpl.bigThreeDev && econTier < BotTeamFactory.eliteMinEconomyTier) {
        continue;
      }

      final t =
          BotTeamFactory.clampTeamTypeToEconomyTier(spec.tier, econTier);
      final allowBigBudget = tmpl.bigThreeDev &&
          econTier >= BotTeamFactory.eliteMinEconomyTier;
      final bc = BotTeamFactory.budgetClassFor(
        t,
        bigThreeDev: allowBigBudget,
      );
      botEntries.add(
        LeagueStandingEntry(
          teamName: spec.displayName,
          isPlayer: false,
          globalId: tmpl.globalId,
          basePower: BotTeamFactory.rollBasePower(_rng, t),
          titlesCount: BotTeamFactory.rollTitles(_rng, t),
          teamType: t,
          budgetClass: bc,
        ),
      );
      _finalizeBigThreeBudget(botEntries.last, branch);
    }

    final fillerTarget = (n - 1) - botEntries.length;

    final pool = [..._nationalBotClubNames]..shuffle(_rng);
    final botNames = <String>[];
    for (final name in pool) {
      if (botNames.length >= fillerTarget) break;
      final trimmed = name.trim();
      if (reserved.contains(trimmed)) continue;
      if (trimmed == clubName.trim()) continue;
      if (botNames.contains(name)) continue;
      botNames.add(name);
    }
    var k = 1;
    while (botNames.length < fillerTarget) {
      final guest = 'Misafir Kulüp ${city.isNotEmpty ? city[0] : "X"}$k';
      k++;
      if (reserved.contains(guest) || botNames.contains(guest)) continue;
      botNames.add(guest);
    }

    final typeOrder = BotTeamFactory.allocateTypes(
      botCount: fillerTarget,
      leagueEconomyTier: econTier,
      rng: _rng,
    );

    for (var i = 0; i < botNames.length; i++) {
      final t = i < typeOrder.length ? typeOrder[i] : TeamType.underdog;
      final budget = BotTeamFactory.budgetFor(t);
      botEntries.add(
        LeagueStandingEntry(
          teamName: botNames[i],
          isPlayer: false,
          basePower: BotTeamFactory.rollBasePower(_rng, t),
          titlesCount: BotTeamFactory.rollTitles(_rng, t),
          teamType: t,
          budgetClass: budget,
        ),
      );
    }

    final entries = <LeagueStandingEntry>[
      LeagueStandingEntry(
        teamName: clubName,
        isPlayer: true,
        titlesCount: 0,
      ),
      ...botEntries,
    ];
    entries.shuffle(_rng);
    return entries;
  }

  /// Eski kayıtlardaki bot satırlarına tip ve güç atanır.
  void _migrateLegacyBotRows(String branch) {
    final t = _leagueStandings[branch];
    if (t == null) return;

    final leagueIdx = _branchLeagueIndices[branch] ?? 0;
    final econ = BranchLeagueData.economyTierInt(branch, leagueIdx);

    for (final e in t) {
      if (e.isPlayer) continue;

      final big3 = GlobalClubCatalog.isBigThreeFranchise(e.globalId);

      if (e.teamType == null) {
        e.teamType = TeamType.stable;
      }

      if (e.teamType == TeamType.elite &&
          econ < BotTeamFactory.eliteMinEconomyTier) {
        e.teamType = TeamType.contender;
      }

      if (!big3 || econ < BotTeamFactory.eliteMinEconomyTier) {
        e.budgetClass = BotTeamFactory.budgetClassFor(
          e.teamType ?? TeamType.stable,
          bigThreeDev: false,
        );
      }

      _finalizeBigThreeBudget(e, branch);

      if (e.basePower <= 0 && e.teamType != null) {
        e.basePower = BotTeamFactory.rollBasePower(_rng, e.teamType!);
      }
      if (e.titlesCount < 0) e.titlesCount = 0;
    }
  }



  List<int> _leagueCalendarWeeksFor(String branch) {
    return _leagueCalendarWeeksMemo.putIfAbsent(branch, () {
      final xs = <int>[];
      for (var w = 1; w <= _seasonLength; w++) {
        if (BranchLeagueData.hasLeagueMatchWeek(branch, w)) {
          xs.add(w);
        }
      }
      return xs;
    });
  }

  void _invalidateLeagueCalendarMemo() =>
      _leagueCalendarWeeksMemo.clear();

  static List<List<(String, String)>> _buildBergerFixture(
    Random rng,
    List<String> teamNames,
    int rounds,
  ) {
    if (teamNames.length < 2 || rounds <= 0) return [];

    final sorted = [...teamNames]..sort();
    sorted.shuffle(rng);

    var desk = [...sorted];
    if (desk.length.isOdd) {
      desk.add('_BYE_');
    }

    List<(String, String)> oneRound(List<String> d) {
      final n = d.length;
      final out = <(String, String)>[];
      for (var i = 0; i < n ~/ 2; i++) {
        final a = d[i];
        final b = d[n - 1 - i];
        if (a == '_BYE_' || b == '_BYE_') continue;
        out.add((a, b));
      }
      return out;
    }

    void rotateDesk(List<String> d) {
      if (d.length < 4) return;
      final head = d[0];
      final slice = [...d.sublist(1)];
      final mover = slice.removeLast();
      d
        ..clear()
        ..add(head)
        ..add(mover)
        ..addAll(slice);
    }

    final cycleLen = max(1, desk.length - 1);
    final single = <List<(String, String)>>[];
    for (var i = 0; i < cycleLen; i++) {
      single.add(oneRound(desk));
      rotateDesk(desk);
    }

    final out = <List<(String, String)>>[];
    var flipHomeAway = false;
    while (out.length < rounds) {
      for (final r in single) {
        if (out.length >= rounds) break;
        if (flipHomeAway) {
          out.add(r.map((e) => (e.$2, e.$1)).toList());
        } else {
          out.add(List<(String, String)>.from(r));
        }
      }
      flipHomeAway = !flipHomeAway;
    }

    while (out.length > rounds) {
      out.removeLast();
    }
    return out;
  }

  void _regenerateSeasonFixturePlans() {
    final club = _currentClub;
    _invalidateLeagueCalendarMemo();
    _seasonFixturePlans.clear();
    if (club == null) return;

    for (final branch in [
      CountryData.football,
      CountryData.basketball,
      CountryData.volleyball,
    ]) {
      final table = _leagueStandings[branch];
      if (table == null || table.length < 2) continue;

      final names = table.map((e) => e.teamName.trim()).toList();
      final roundsNeeded =
          BranchLeagueData.leagueMatchWeeksInSeason(branch).clamp(1, _seasonLength);
      _seasonFixturePlans[branch] =
          _buildBergerFixture(_rng, names, roundsNeeded);
    }
  }

  List<(LeagueStandingEntry, LeagueStandingEntry)> _scheduledPairsOrShuffle(
      String branch, int calendarWeek, List<LeagueStandingEntry> table) {
    final weeks = _leagueCalendarWeeksFor(branch);
    final ix = weeks.indexOf(calendarWeek);

    LeagueStandingEntry? resolve(String nm) {
      final t = nm.trim();
      for (final e in table) {
        if (e.teamName.trim() == t) return e;
      }
      return null;
    }

    final plan = _seasonFixturePlans[branch];
    if (plan == null || ix < 0 || ix >= plan.length) {
      return _pairLeagueForWeek(table);
    }

    final out = <(LeagueStandingEntry, LeagueStandingEntry)>[];
    for (final (hNm, aNm) in plan[ix]) {
      final h = resolve(hNm);
      final a = resolve(aNm);
      if (h != null && a != null) {
        out.add((h, a));
      }
    }
    return out.isNotEmpty ? out : _pairLeagueForWeek(table);
  }

  void _trimMatchArchive() {
    while (_matchHistory.length > _matchArchiveSoftCap) {
      _matchHistory.removeAt(0);
    }
  }

  void _appendPlayerLeagueArchive({
    required String branch,
    required LeagueStandingEntry opponent,
    required int playerGoalsFor,
    required int playerGoalsAgainst,
    required int simulatedCalendarWeek,
  }) {
    final club = _currentClub;
    if (club == null) return;

    var home = club.name.trim();
    var away = opponent.teamName.trim();

    final weeks = _leagueCalendarWeeksFor(branch);
    final ri = weeks.indexOf(simulatedCalendarWeek);
    if (ri >= 0) {
      final planRound = _seasonFixturePlans[branch];
      if (planRound != null && ri < planRound.length) {
        for (final (hNm, aNm) in planRound[ri]) {
          final hm = club.name.trim() == hNm.trim();
          final am = opponent.teamName.trim() == aNm.trim();
          final mh = club.name.trim() == aNm.trim();
          final mh2 = opponent.teamName.trim() == hNm.trim();
          if ((hm && am) || (mh && mh2)) {
            home = hNm.trim();
            away = aNm.trim();
            break;
          }
        }
      }
    }

    final playerHome = club.name.trim() == home;
    final hg = playerHome ? playerGoalsFor : playerGoalsAgainst;
    final ag = playerHome ? playerGoalsAgainst : playerGoalsFor;

    _trimMatchArchive();
    _matchHistory.add(MatchResult(
      branch: branch,
      seasonNumber: _seasonNumber,
      calendarWeek: simulatedCalendarWeek,
      homeTeam: home,
      awayTeam: away,
      homeGoals: hg,
      awayGoals: ag,
      playerIsHomeSlot: playerHome,
      playerClubName: club.name,
      goalsFor: playerGoalsFor,
      goalsAgainst: playerGoalsAgainst,
    ));
  }

  int _consumeMoraleForBranch(String branch) {
    final v = _branchMoraleNextFixture[branch] ?? 0;
    if (v != 0) _branchMoraleNextFixture.remove(branch);
    return v.clamp(-10, 10);
  }

  void _accumulateMorale(RandomEventOption o) {
    if (o.moraleFormDelta == 0) return;
    void bump(String bb) {
      final cur = _branchMoraleNextFixture[bb] ?? 0;
      final n = (cur + o.moraleFormDelta).clamp(-10, 10);
      if (n == 0) {
        _branchMoraleNextFixture.remove(bb);
      } else {
        _branchMoraleNextFixture[bb] = n;
      }
    }

    final target = o.moraleTargetBranch;
    if (target != null && target.trim().isNotEmpty) {
      bump(target.trim());
      return;
    }
    for (final bb in [
      CountryData.football,
      CountryData.basketball,
      CountryData.volleyball,
    ]) {
      bump(bb);
    }
  }

  List<(LeagueStandingEntry, LeagueStandingEntry)> _pairLeagueForWeek(
      List<LeagueStandingEntry> table) {
    final shuffled = [...table]..shuffle(_rng);
    final out = <(LeagueStandingEntry, LeagueStandingEntry)>[];
    for (var i = 0; i + 1 < shuffled.length; i += 2) {
      out.add((shuffled[i], shuffled[i + 1]));
    }
    return out;
  }

  void _rollWeeklyFormAllBranches() {
    for (final branch in [
      CountryData.football,
      CountryData.basketball,
      CountryData.volleyball,
    ]) {
      final t = _leagueStandings[branch];
      if (t == null) continue;
      for (final e in t) {
        e.weeklyForm = _rng.nextInt(7) - 3;
      }
    }
  }

  /// Oyuncunun haftalık puanı: başarı oranı + form + rakip dinamik gücü.
  int _weeklyPointsVsOpponent(
    double successRate,
    int playerWeeklyForm,
    LeagueStandingEntry opponent,
  ) {
    final botCore = opponent.basePower > 0
        ? opponent.basePower
        : BotTeamFactory.rollBasePower(_rng, opponent.teamType ?? TeamType.stable);
    if (opponent.basePower <= 0 && !opponent.isPlayer) {
      opponent.basePower = botCore;
    }
    final botSide = botCore + opponent.weeklyForm;
    final playerSide = successRate * 100 + playerWeeklyForm;
    final adj = (successRate + (playerSide - botSide) / 180.0).clamp(0.08, 0.92);
    return _weeklyPoints(adj);
  }

  void _simulateLeagueRound(List<WeeklyMatchResult> weekResults) {
    const branches = [
      CountryData.football, CountryData.basketball, CountryData.volleyball,
    ];
    for (final branch in branches) {
      final matches = weekResults.where((r) => r.branch == branch);
      if (matches.isEmpty) continue;
      final wr = matches.first;
      if (!wr.hadLeagueMatch) continue;
      final pairs = _weekLeaguePairings[branch];
      if (pairs == null) continue;

      for (final (a, b) in pairs) {
        _resolveStandingsPair(a, b, branch, wr);
      }
    }
  }

  void _resolveStandingsPair(
    LeagueStandingEntry a,
    LeagueStandingEntry b,
    String branch,
    WeeklyMatchResult wr,
  ) {
    if (a.isPlayer) {
      _applyPlayerLeagueMatch(a, branch, wr);
      _applyOpponentVersusPlayer(b, wr);
      return;
    }
    if (b.isPlayer) {
      _applyPlayerLeagueMatch(b, branch, wr);
      _applyOpponentVersusPlayer(a, wr);
      return;
    }
    _simulateBotVersusBot(a, b);
  }

  void _applyPlayerLeagueMatch(
      LeagueStandingEntry p, String branch, WeeklyMatchResult wr) {
    p.played++;
    p.goalsFor += wr.goalsFor;
    p.goalsAgainst += wr.goalsAgainst;
    switch (wr.outcome) {
      case MatchOutcome.win:
        p.wins++;
      case MatchOutcome.draw:
        p.draws++;
      case MatchOutcome.loss:
        p.losses++;
    }
    p.points = _branchPoints[branch] ?? p.points;
  }

  void _applyOpponentVersusPlayer(LeagueStandingEntry bot, WeeklyMatchResult wr) {
    bot.played++;
    bot.goalsFor += wr.goalsAgainst;
    bot.goalsAgainst += wr.goalsFor;
    switch (wr.outcome) {
      case MatchOutcome.win:
        bot.losses++;
      case MatchOutcome.draw:
        bot.draws++;
        bot.points++;
      case MatchOutcome.loss:
        bot.wins++;
        bot.points += 3;
    }
  }

  void _simulateBotVersusBot(LeagueStandingEntry a, LeagueStandingEntry b) {
    a.played++;
    b.played++;

    int core(LeagueStandingEntry e) {
      if (e.basePower > 0) return e.basePower;
      final t = e.teamType ?? TeamType.stable;
      e.basePower = BotTeamFactory.rollBasePower(_rng, t);
      return e.basePower;
    }

    final pa = core(a) + a.weeklyForm + _rng.nextInt(7) - 3;
    final pb = core(b) + b.weeklyForm + _rng.nextInt(7) - 3;

    MatchOutcome forA;
    final diff = pa - pb;
    if (diff >= 10) {
      forA = MatchOutcome.win;
    } else if (diff <= -10) {
      forA = MatchOutcome.loss;
    } else {
      final winP = (0.33 + diff * 0.025).clamp(0.08, 0.72);
      final r = _rng.nextDouble();
      if (r < winP) {
        forA = MatchOutcome.win;
      } else if (r < winP + 0.28) {
        forA = MatchOutcome.draw;
      } else {
        forA = MatchOutcome.loss;
      }
    }

    switch (forA) {
      case MatchOutcome.win:
        final gs = 1 + _rng.nextInt(3);
        final gc = _rng.nextInt(gs);
        a.wins++;
        a.points += 3;
        b.losses++;
        a.goalsFor += gs;
        a.goalsAgainst += gc;
        b.goalsFor += gc;
        b.goalsAgainst += gs;
      case MatchOutcome.draw:
        final g = 1 + _rng.nextInt(2);
        a.draws++;
        b.draws++;
        a.points++;
        b.points++;
        a.goalsFor += g;
        a.goalsAgainst += g;
        b.goalsFor += g;
        b.goalsAgainst += g;
      case MatchOutcome.loss:
        final gs = 1 + _rng.nextInt(3);
        final gc = _rng.nextInt(gs);
        b.wins++;
        b.points += 3;
        a.losses++;
        b.goalsFor += gs;
        b.goalsAgainst += gc;
        a.goalsFor += gc;
        a.goalsAgainst += gs;
    }
  }

  (int gf, int ga) _randomScoreLine(MatchOutcome outcome) {
    switch (outcome) {
      case MatchOutcome.win:
        final gfor = 2 + _rng.nextInt(2);
        final ga = gfor > 1 ? _rng.nextInt(gfor) : 0;
        return (gfor, ga);
      case MatchOutcome.draw:
        final g = 1 + _rng.nextInt(2);
        return (g, g);
      case MatchOutcome.loss:
        final gagainst = 2 + _rng.nextInt(2);
        final gf = gagainst > 1 ? _rng.nextInt(gagainst) : 0;
        return (gf, gagainst);
    }
  }

  /// Kayıtta tablo yoksa veya bozuksa yeniden kurar.
  void _ensureLeagueStandingsLoaded() {
    final club = _currentClub;
    if (club == null) return;
    for (final branch in [
      CountryData.football, CountryData.basketball, CountryData.volleyball,
    ]) {
      final t = _leagueStandings[branch];
      final expect = BranchLeagueData.leagueTeamCount(
          branch, _branchLeagueIndices[branch] ?? 0);
      if (t == null ||
          t.length != expect ||
          !t.any((e) => e.isPlayer)) {
        _leagueStandings[branch] =
            _buildStandingsTableForBranch(club.name, club.city, branch);
      } else {
        _migrateLegacyBotRows(branch);
      }
    }
  }

  // ── Kulüp Kurulum ──────────────────────────────────────────────────────────

  void createClub({
    required String clubName,
    required String city,
    required String primaryColor,
    required String secondaryColor,
    required String presidentName,
    required int    presidentAge,
    double presidentReputation = 0.3,
    int    presidentCharisma   = 40,
    Map<String, double>? branchBudgets,
  }) {
    _branchLeagueIndices.updateAll((k, v) => 0);
    _branchPoints.updateAll((k, v) => 0);
    _facilityLevels.updateAll((k, v) => 0);
    _infrastructureLevels.updateAll((k, v) => 0);
    _marketingLevels.updateAll((k, v) => 0);
    _activeSponsors.clear();
    _namingRightsSeasons.clear();
    _branchCupRound.updateAll((k, v) => CupRound.r1);
    _branchCupFarthest.clear();
    _lastCupResults = [];
    _currentWeek      = 1;
    _seasonNumber     = 1;
    _calendarYear     = museumCalendarBaseYear;
    _lastSeasonResults = null;
    _lastWeekResults   = [];
    _lastEconomySummary = null;
    _pendingRandomPresidentEvent = null;

    _facilityNamingSold.updateAll((k, v) => false);
    _facilityNamingLabel.updateAll((k, v) => null);
    _leagueStandings.clear();
    _trophyRoom.clear();
    _seasonFixturePlans.clear();
    _invalidateLeagueCalendarMemo();
    _matchHistory.clear();
    _branchMoraleNextFixture.clear();
    _weeksAccumulatedPresident = 0;
    _presidentNextGapWeeks = 3 + _rng.nextInt(2);

    _currentClub = Club(
      name: clubName, city: city,
      primaryColor: primaryColor, secondaryColor: secondaryColor,
      treasury: GameProvider.initialTreasuryEuros, debt: 0, reputation: 20,
      branches: _buildBranches(budgets: branchBudgets, reputation: 20),
    );

    _currentPresident = President(
      name: presidentName, age: presidentAge,
      personalReputation: presidentReputation, charisma: presidentCharisma,
    );

    _initLeagueStandingsTables();
    _regenerateSeasonFixturePlans();

    _generateSponsorOffers();
    _needsSponsorSelection = true;

    notifyListeners();
    saveGame(); // Yeni kulüp kurulduğunda hemen kaydet
  }

  void updateClub(Club updated) {
    _currentClub = updated;
    notifyListeners();
  }

  void updatePresident(President updated) {
    _currentPresident = updated;
    notifyListeners();
  }

  // ── Sponsorluk ─────────────────────────────────────────────────────────────

  void selectSponsor(String branch, SponsorOffer offer) {
    final club = _currentClub;
    if (club == null) return;

    _activeSponsors[branch] = ActiveSponsor(
      offer: offer,
      contractSeasons: offer.contractSeasons,
    );

    // Naming rights → sözleşme takibini başlat
    if (offer.isNamingRights && offer.contractSeasons != null) {
      _namingRightsSeasons[branch] = offer.contractSeasons!;
    }

    // Peşinat + itibar
    final rep = (club.reputation + offer.reputationBonus).clamp(0, 100);
    _currentClub = club.copyWith(
      treasury:   club.treasury + offer.upfrontPayment,
      reputation: rep,
    );
    notifyListeners();
  }

  /// Tüm branşlar seçildikten sonra sezon penceresini kapat.
  void completeSponsorSelection() {
    _needsSponsorSelection = false;
    notifyListeners();
  }

  // ── Seçimli Olay ───────────────────────────────────────────────────────────

  void resolvePresidentRandomEvent(bool pickFirstOption) {
    final ev = _pendingRandomPresidentEvent;
    if (ev == null) return;
    final option = pickFirstOption ? ev.optionA : ev.optionB;

    var club = _currentClub;
    if (club == null) return;

    var updatedBranches = List<Branch>.from(club.branches);

    if (option.fanInterestDelta != 0) {
      for (var i = 0; i < updatedBranches.length; i++) {
        final br = updatedBranches[i];
        if (option.targetBranch != null &&
            br.name != option.targetBranch) {
          continue;
        }
        final newFI = (br.fanInterest + option.fanInterestDelta).clamp(0, 100);
        final ligIdx = _branchLeagueIndices[br.name] ?? 0;
        final infraLvl = _infrastructureLevels[br.name] ?? 0;
        final infraBonus =
            InvestmentCatalog.infrastructureSuccessBonus(infraLvl, ligIdx);
        final repSr = _clubSuccessRateReputationBonus(reputation: club.reputation);
        final newSR = (BranchLeagueData.calcSuccessRate(
                  branch: br.name,
                  budget: br.budget,
                  levelIndex: ligIdx,
                  fanInterest: newFI,
                  infrastructureLevel: 0,
                ) +
                infraBonus +
                repSr)
            .clamp(0.0, 1.0);
        updatedBranches[i] = br.copyWith(fanInterest: newFI, successRate: newSR);
      }
    }

    final newRep = (club.reputation + option.reputationDelta).clamp(0, 100);
    _currentClub = club.copyWith(
      treasury: club.treasury + option.treasuryDelta,
      reputation: newRep,
      branches: updatedBranches,
    );
    _accumulateMorale(option);
    _pendingRandomPresidentEvent = null;
    notifyListeners();
    saveGame();
  }

  /// Geriye uyum: 0=A, 1=B.
  void resolveChoiceEvent(int optionIndex) =>
      resolvePresidentRandomEvent(optionIndex == 0);

  // ── Yatırım ────────────────────────────────────────────────────────────────

  /// Yatırım satın alır. Yeterli kasa yoksa false döner.
  bool purchaseInvestment(String branch, InvestmentType type) {
    final club = _currentClub;
    if (club == null) return false;

    final currentLevel = switch (type) {
      InvestmentType.facility       => _facilityLevels[branch] ?? 0,
      InvestmentType.infrastructure => _infrastructureLevels[branch] ?? 0,
      InvestmentType.marketing      => _marketingLevels[branch] ?? 0,
    };

    final tier = InvestmentCatalog.nextTier(type, currentLevel);
    if (tier == null) return false;          // max seviyede
    if (club.treasury < tier.cost) return false; // yetersiz kasa

    switch (type) {
      case InvestmentType.facility:
        _facilityLevels[branch] = tier.level;
      case InvestmentType.infrastructure:
        _infrastructureLevels[branch] = tier.level;
        _recalcBranchSuccessRate(branch); // hemen güncelle
      case InvestmentType.marketing:
        _marketingLevels[branch] = tier.level;
    }

    _currentClub = club.copyWith(treasury: club.treasury - tier.cost);
    notifyListeners();
    saveGame();
    return true;
  }

  /// Genel kasadan branş bütçesine kalıcı aktarım (finansal süreklilik).
  /// Bütçe düşürme desteklenmez.
  bool topUpBranchBudgetFromTreasury(String branch, double amount) {
    final club = _currentClub;
    if (club == null || amount <= 0) return false;
    if (club.treasury + 0.01 < amount) return false;

    var found = false;
    final nextBranches = club.branches.map((b) {
      if (b.name != branch) return b;
      found = true;
      return b.copyWith(budget: b.budget + amount);
    }).toList();
    if (!found) return false;

    _currentClub = club.copyWith(
      treasury: club.treasury - amount,
      branches: nextBranches,
    );
    _recalcBranchSuccessRate(branch);
    notifyListeners();
    saveGame();
    return true;
  }

  // ── Sezon Simülasyonu ──────────────────────────────────────────────────────

  /// Bilet/yayın için itibar: temel üzerine en fazla ~%10 (+itibar/10 puan).
  double _clubReputationIncomeMultiplier({int? reputation}) {
    final r = (reputation ?? (_currentClub?.reputation ?? 0)).clamp(0, 100);
    return 1.0 + (r / 100.0) * 0.10;
  }

  /// Maç simülasyonu: itibar/(20×100) oranında `successRate` bonusu → itibar / 2000.
  double _clubSuccessRateReputationBonus({int? reputation}) {
    final r = (reputation ?? (_currentClub?.reputation ?? 0)).clamp(0, 100);
    return r / 2000.0;
  }

  void advanceWeek() {
    if (isSeasonOver) return;
    var club = _currentClub;
    if (club == null) return;

    const branches = [
      CountryData.football, CountryData.basketball, CountryData.volleyball,
    ];

    _weekLeaguePairings.clear();
    _rollWeeklyFormAllBranches();

    // 1. Maç simülasyonu + fan interest güncellemesi
    final weekResults = <WeeklyMatchResult>[];
    var updatedBranches = List<Branch>.from(club.branches);

    for (final branchName in branches) {
      final idx = updatedBranches.indexWhere((b) => b.name == branchName);
      if (idx == -1) continue;
      final b = updatedBranches[idx];

      final playsLeague =
          BranchLeagueData.hasLeagueMatchWeek(branchName, _currentWeek);

      if (!playsLeague) {
        weekResults.add(WeeklyMatchResult(
          branch: branchName,
          points: 0,
          outcome: MatchOutcome.draw,
          hadLeagueMatch: false,
        ));
        continue;
      }

      final table = _leagueStandings[branchName];
      if (table != null) {
        _migrateLegacyBotRows(branchName);
        final pairs = _scheduledPairsOrShuffle(branchName, _currentWeek, table);
        _weekLeaguePairings[branchName] = pairs;
      }

      LeagueStandingEntry? opp;
      final pairs = _weekLeaguePairings[branchName];
      if (pairs != null) {
        for (final (x, y) in pairs) {
          if (x.isPlayer) {
            opp = y;
            break;
          }
          if (y.isPlayer) {
            opp = x;
            break;
          }
        }
      }

      final ligIdx = _branchLeagueIndices[branchName] ?? 0;
      final infraLvl = _infrastructureLevels[branchName] ?? 0;
      final infraBonus =
          InvestmentCatalog.infrastructureSuccessBonus(infraLvl, ligIdx);
      final baseSr = BranchLeagueData.calcSuccessRate(
        branch: branchName,
        budget: b.budget,
        levelIndex: ligIdx,
        fanInterest: b.fanInterest,
        infrastructureLevel: 0,
      );
      final repSr = _clubSuccessRateReputationBonus(reputation: club.reputation);
      final sr = (baseSr + infraBonus + repSr).clamp(0.0, 1.0);

      LeagueStandingEntry? playerRow;
      if (table != null) {
        for (final e in table) {
          if (e.isPlayer) {
            playerRow = e;
            break;
          }
        }
      }
      final pForm = playerRow?.weeklyForm ?? 0;

      final moraleEdge = _consumeMoraleForBranch(branchName);

      final pts = opp != null
          ? _weeklyPointsVsOpponent(sr, pForm + moraleEdge, opp)
          : _weeklyPoints(sr);
      _branchPoints[branchName] = (_branchPoints[branchName] ?? 0) + pts;

      final outcome = switch (pts) {
        3 => MatchOutcome.win,
        1 => MatchOutcome.draw,
        _ => MatchOutcome.loss,
      };
      final (gf, ga) = _randomScoreLine(outcome);
      weekResults.add(WeeklyMatchResult(
        branch: branchName,
        points: pts,
        outcome: outcome,
        hadLeagueMatch: true,
        goalsFor: gf,
        goalsAgainst: ga,
      ));

      if (opp != null) {
        _appendPlayerLeagueArchive(
          branch: branchName,
          opponent: opp,
          playerGoalsFor: gf,
          playerGoalsAgainst: ga,
          simulatedCalendarWeek: _currentWeek,
        );
      }

      if (outcome == MatchOutcome.win) {
        _activeSponsors[branchName]?.seasonWins++;
      }

      final fanDelta = switch (outcome) {
        MatchOutcome.win  => 2,
        MatchOutcome.loss => -1,
        MatchOutcome.draw => 0,
      };
      final newFI = (b.fanInterest + fanDelta).clamp(0, 100);
      final newSR = (BranchLeagueData.calcSuccessRate(
            branch: branchName,
            budget: b.budget,
            levelIndex: ligIdx,
            fanInterest: newFI,
            infrastructureLevel: 0,
          ) +
          infraBonus +
          repSr)
          .clamp(0.0, 1.0);
      updatedBranches[idx] = b.copyWith(fanInterest: newFI, successRate: newSR);
    }

    _simulateLeagueRound(weekResults);

    // 2. Kupa maçı (her 4 haftada bir) — önce oynansın, sonuçlar ekonomiye dahil
    double cupPrizeTotal = 0;
    if (_cupWeekMap.containsKey(_currentWeek)) {
      final cupResults = _playCupMatchesThisWeek(updatedBranches);
      _lastCupResults = cupResults;
      for (final r in cupResults) { cupPrizeTotal += r.prizeEarned; }
    } else {
      _lastCupResults = [];
    }

    // 3. Dinamik Ödül Sistemi: bilet + yayın + maç primi + bakım
    double totalRevenue       = 0;
    double totalCosts         = 0;
    double sponsorWinBonus    = 0;
    double broadcastingTotal  = 0;
    double matchPrizeTotal    = 0;
    final breakdown           = <BranchWeeklyIncome>[];

    final repIncomeMult =
        _clubReputationIncomeMultiplier(reputation: club.reputation);

    for (final b in updatedBranches) {
      final levelIdx = _branchLeagueIndices[b.name] ?? 0;

      // Yatırım verimlilik katsayıları
      final facilLvl = _facilityLevels[b.name] ?? 0;
      final mktLvl   = _marketingLevels[b.name] ?? 0;
      final mktBonus  = InvestmentCatalog.marketingRevenueBonus(mktLvl, levelIdx);

      // Bilet geliri (+pazarlama bonus) × itibar çarpanı
      final ticketBase = BranchLeagueData.ticketRevenue(
        b.name, b.fanInterest, levelIdx,
        marketingLevel: 0, // marketingLevel artık burada uygulanmıyor
      );
      final ticket = ticketBase * (1.0 + mktBonus) * repIncomeMult;

      // Yayın geliri (pazarlamadan pay) × itibar çarpanı
      final broadcastBase = BranchLeagueData.broadcastingRevenue(b.name, levelIdx);
      final broadcast = broadcastBase * (1.0 + mktBonus * 0.5) * repIncomeMult;
      broadcastingTotal += broadcast;

      // Maç primi (galibiyet / beraberlik)
      final matchResult = weekResults.firstWhere(
        (r) => r.branch == b.name,
        orElse: () => WeeklyMatchResult(
            branch: b.name,
            points: 0,
            outcome: MatchOutcome.draw,
            hadLeagueMatch: false),
      );
      final prize = (matchResult.hadLeagueMatch
              ? BranchLeagueData.matchPrize(b.name, levelIdx, matchResult.outcome)
              : 0)
          .toDouble();
      matchPrizeTotal += prize;

      // Sponsor win bonus
      double sponsorB = 0;
      if (matchResult.hadLeagueMatch &&
          matchResult.outcome == MatchOutcome.win) {
        sponsorB = _activeSponsors[b.name]?.offer.winBonus ?? 0;
        sponsorWinBonus += sponsorB;
      }

      // Kupa primi (bu branşın kupadan aldığı)
      final cupB = _lastCupResults
          .where((r) => r.branch == b.name)
          .fold(0.0, (s, r) => s + r.prizeEarned);

      // Bakım gideri — tesis yatırımı azaltır
      final facilReduction = InvestmentCatalog.facilityMaintenanceReduction(
          facilLvl, levelIdx);
      final rawMaintenance =
          BranchLeagueData.maintenanceCost(b.name, b.budget, levelIdx)
              * (1 + (_seasonNumber - 1) * 0.05);
      final maintenance = rawMaintenance * (1.0 - facilReduction);

      breakdown.add(BranchWeeklyIncome(
        branch:              b.name,
        ticketRevenue:       ticket,
        broadcastingRevenue: broadcast,
        matchPrize:          prize,
        sponsorBonus:        sponsorB,
        cupPrize:            cupB,
        maintenanceCost:     maintenance,
        outcome:             matchResult.outcome,
      ));

      totalRevenue += ticket + broadcast + prize + sponsorB + cupB;
      totalCosts   += maintenance;
    }

    // 4. Başkanlık olayları (ortalama her 3–4 hafta)
    _weeksAccumulatedPresident++;
    if (_pendingRandomPresidentEvent == null &&
        !_needsSponsorSelection &&
        _currentClub != null) {
      if (_weeksAccumulatedPresident >= _presidentNextGapWeeks) {
        _pendingRandomPresidentEvent =
            presidentRandomCatalog[_rng.nextInt(presidentRandomCatalog.length)];
        _weeksAccumulatedPresident = 0;
        _presidentNextGapWeeks = 3 + _rng.nextInt(2);
      }
    }

    final netChange = totalRevenue - totalCosts;

    // 5. Kulübü güncelle
    club = club.copyWith(
      treasury: club.treasury + netChange,
      branches: updatedBranches,
    );
    _currentClub = club;

    // 6. State kayıt
    _lastWeekResults    = weekResults;
    _lastEconomySummary = WeeklyEconomySummary(
      totalRevenue:      totalRevenue,
      totalCosts:        totalCosts,
      netChange:         netChange,
      sponsorWinBonus:   sponsorWinBonus,
      cupPrizeTotal:     cupPrizeTotal,
      broadcastingTotal: broadcastingTotal,
      matchPrizeTotal:   matchPrizeTotal,
      hadCupMatch:       _lastCupResults.isNotEmpty,
      breakdown:         breakdown,
    );

    _currentWeek++;
    if (_currentWeek > _seasonLength) _lastSeasonResults = _resolveSeasonEnd();

    notifyListeners();
    saveGame(); // Otomatik kayıt (fire-and-forget)
  }

  List<BranchSeasonResult> _resolveSeasonEnd() {
    const branches = [
      CountryData.football, CountryData.basketball, CountryData.volleyball,
    ];
    final results = <BranchSeasonResult>[];

    double totalRankingBonus = 0;
    var podiumTrophyAdded = false;

    for (final branch in branches) {
      final pts = _branchPoints[branch] ?? 0;
      final levelAtEnd = _branchLeagueIndices[branch] ?? 0;
      final table = standingsForBranch(branch);
      final rank = table.indexWhere((e) => e.isPlayer) + 1;
      final teamN =
          BranchLeagueData.leagueTeamCount(branch, levelAtEnd);

      final prom = BranchLeagueData.promoteSlots(branch, levelAtEnd);
      final rel = BranchLeagueData.relegateSlots(branch, levelAtEnd);

      var promoted = false;
      var relegated = false;

      if (!BranchLeagueData.isTopLeague(branch, levelAtEnd) &&
          prom > 0 &&
          rank > 0 &&
          rank <= prom) {
        promoted = true;
        _branchLeagueIndices[branch] = levelAtEnd + 1;
        _recalcBranchSuccessRate(branch);
      } else if (!BranchLeagueData.isBottomLeague(branch, levelAtEnd) &&
          rel > 0 &&
          rank > 0 &&
          rank > teamN - rel) {
        relegated = true;
        _branchLeagueIndices[branch] = levelAtEnd - 1;
        _recalcBranchSuccessRate(branch);
      }

      final rankBonus =
          BranchLeagueData.rankingBonusByRank(branch, levelAtEnd, rank);
      totalRankingBonus += rankBonus;

      double penalty = 0;
      final sponsor = _activeSponsors[branch];
      if (sponsor != null && sponsor.offer.pointTarget != null) {
        if (pts < sponsor.offer.pointTarget!) {
          penalty = sponsor.offer.upfrontPayment * sponsor.offer.penaltyFactor;
        }
      }

      // Müze: her branş (Futbol, Basketbol, Voleybol) için ayrı kürsü 1–3;
      // branchId ↔ BranchKeys (global_club_catalog ile aynı dizeler).
      if (rank >= 1 && rank <= 3) {
        final branchId = switch (branch) {
          CountryData.football => BranchKeys.football,
          CountryData.basketball => BranchKeys.basketball,
          CountryData.volleyball => BranchKeys.volleyball,
          _ => branch,
        };
        _trophyRoom.add(Trophy(
          branch: branch,
          branchId: branchId,
          rank: rank,
          seasonCompleted: _seasonNumber,
          leagueName: BranchLeagueData.leagueName(branch, levelAtEnd),
          completedSeasonYearMark:
              GameProvider.museumYearForEndedSeason(_seasonNumber),
        ));
        podiumTrophyAdded = true;
      }

      results.add(BranchSeasonResult(
        branch:             branch,
        totalPoints:        pts,
        promoted:           promoted,
        relegated:          relegated,
        tableRank:          rank,
        newLeagueName:      branchLeagueName(branch),
        terminationPenalty: penalty,
        rankingBonus:       rankBonus,
        cupProgress:        _buildCupLabel(branch),
      ));
    }

    final club = _currentClub;
    if (club != null) {
      final totalPenalty = results.fold(0.0, (s, r) => s + r.terminationPenalty);
      final netSeasonEnd = totalRankingBonus - totalPenalty;
      _currentClub = club.copyWith(
        treasury: (club.treasury + netSeasonEnd).clamp(0, double.infinity),
      );
    }

    for (final branch in branches) {
      _applyEndOfSeasonDynamicPower(branch);
    }

    if (podiumTrophyAdded) {
      notifyListeners();
    }

    return results;
  }

  /// Sezon bitiminde: sıralamaya göre BasePower güncelle +
  /// kürsü (ilk 3) için başarı / [titlesCount] güncellemesi.
  void _applyEndOfSeasonDynamicPower(String branch) {
    final ordered = standingsForBranch(branch);
    if (ordered.isEmpty) return;
    final n = ordered.length;

    final podium = min(3, ordered.length);
    for (var i = 0; i < podium; i++) {
      final e = ordered[i];
      final tableRank = i + 1;
      if (e.isPlayer) {
        if (tableRank == 1) e.titlesCount++;
      } else {
        e.titlesCount++;
      }
    }

    final third = max(1, n ~/ 3);
    for (var i = 0; i < n; i++) {
      final e = ordered[i];
      if (e.isPlayer) continue;
      final rank = i + 1;
      var delta = 0;
      if (rank <= 2) {
        delta = 6;
      } else if (rank <= third) {
        delta = 3;
      } else if (rank > n - third) {
        delta = -5;
      } else {
        delta = -1;
      }
      e.basePower = (e.basePower + delta).clamp(1, 100);
    }
    for (final e in ordered) {
      if (!e.isPlayer) {
        _finalizeBigThreeBudget(e, branch);
      }
    }
  }

  void _resetLeagueStatsInPlace(List<LeagueStandingEntry> table) {
    for (final e in table) {
      e.played = 0;
      e.wins = 0;
      e.draws = 0;
      e.losses = 0;
      e.points = 0;
      e.goalsFor = 0;
      e.goalsAgainst = 0;
      e.weeklyForm = 0;
    }
  }

  /// Küme değişmediyse istatistik sıfırla; takım sayısı değiştiyse tabloyu yeniden kur.
  void _prepareLeagueStandingsForNewSeason() {
    final club = _currentClub;
    if (club == null) return;
    for (final branch in [
      CountryData.football,
      CountryData.basketball,
      CountryData.volleyball,
    ]) {
      final leagueIdx = _branchLeagueIndices[branch] ?? 0;
      final expect =
          BranchLeagueData.leagueTeamCount(branch, leagueIdx).clamp(2, 64);
      final current = _leagueStandings[branch];
      if (current != null &&
          current.length == expect &&
          current.any((e) => e.isPlayer)) {
        _migrateLegacyBotRows(branch);
        _resetLeagueStatsInPlace(current);
        for (final e in current) {
          if (!GlobalClubCatalog.isBigThreeFranchise(e.globalId)) continue;
          _finalizeBigThreeBudget(e, branch);
        }
        current.shuffle(_rng);
      } else {
        _leagueStandings[branch] =
            _buildStandingsTableForBranch(club.name, club.city, branch);
      }
    }
    _regenerateSeasonFixturePlans();
  }

  void startNewSeason() {
    _currentWeek  = 1;
    _seasonNumber++;
    _calendarYear++;
    _branchPoints.updateAll((k, v) => 0);
    _lastSeasonResults  = null;
    _lastWeekResults    = [];
    _lastEconomySummary = null;
    _pendingRandomPresidentEvent = null;

    // Sponsor win sayaçlarını sıfırla; naming rights sözleşmesini düş
    for (final branch in [..._activeSponsors.keys]) {
      _activeSponsors[branch]?.seasonWins = 0;

      if (_namingRightsSeasons.containsKey(branch)) {
        _namingRightsSeasons[branch] = (_namingRightsSeasons[branch] ?? 1) - 1;
        if ((_namingRightsSeasons[branch] ?? 0) <= 0) {
          _namingRightsSeasons.remove(branch);
          _activeSponsors.remove(branch);  // Sözleşme bitti, yeni sponsor seçilecek
        }
      }
    }

    // Kupa durumunu sıfırla
    _branchCupRound.updateAll((k, v) => CupRound.r1);
    _branchCupFarthest.clear();
    _lastCupResults = [];

    _prepareLeagueStandingsForNewSeason();

    _generateSponsorOffers();
    _needsSponsorSelection = true;
    notifyListeners();
  }

  void promoteBranch(String branch) {
    final current = _branchLeagueIndices[branch] ?? 0;
    if (BranchLeagueData.isTopLeague(branch, current)) return;
    _branchLeagueIndices[branch] = current + 1;
    _recalcBranchSuccessRate(branch);
    notifyListeners();
  }

  void relegateBranch(String branch) {
    final current = _branchLeagueIndices[branch] ?? 0;
    if (current <= 0) return;
    _branchLeagueIndices[branch] = current - 1;
    _recalcBranchSuccessRate(branch);
    notifyListeners();
  }

  void resetGame() {
    _currentClub        = null;
    _currentPresident   = null;
    _branchLeagueIndices.updateAll((k, v) => 0);
    _branchPoints.updateAll((k, v) => 0);
    _facilityLevels.updateAll((k, v) => 0);
    _infrastructureLevels.updateAll((k, v) => 0);
    _marketingLevels.updateAll((k, v) => 0);
    _leagueStandings.clear();
    _weekLeaguePairings.clear();
    _seasonFixturePlans.clear();
    _invalidateLeagueCalendarMemo();
    _matchHistory.clear();
    _branchMoraleNextFixture.clear();
    _weeksAccumulatedPresident = 0;
    _presidentNextGapWeeks = 3;
    _trophyRoom.clear();
    _facilityNamingSold.updateAll((k, v) => false);
    _facilityNamingLabel.updateAll((k, v) => null);
    _activeSponsors.clear();
    _pendingSponsorOffers.clear();
    _namingRightsSeasons.clear();
    _branchCupRound.updateAll((k, v) => CupRound.r1);
    _branchCupFarthest.clear();
    _lastCupResults = [];
    _currentWeek        = 1;
    _seasonNumber       = 1;
    _calendarYear       = museumCalendarBaseYear;
    _lastSeasonResults  = null;
    _lastWeekResults    = [];
    _lastEconomySummary = null;
    _pendingRandomPresidentEvent = null;
    _needsSponsorSelection = false;
    notifyListeners();
  }

  // ── Kayıt Sistemi ─────────────────────────────────────────────────────────

  static const _kSaveKey = 'presidento_save_v1';

  /// Tüm oyun durumunu SharedPreferences'a JSON olarak yazar.
  Future<void> saveGame() async {
    final club      = _currentClub;
    final president = _currentPresident;
    if (club == null || president == null) return;

    final data = <String, dynamic>{
      'club':               club.toMap(),
      'president':          president.toMap(),
      'currentWeek':        _currentWeek,
      'seasonNumber':       _seasonNumber,
      'calendarYear':       _calendarYear,
      'branchLeagueIndices':   _branchLeagueIndices,
      'branchPoints':          _branchPoints,
      'facilityLevels':        _facilityLevels,
      'infrastructureLevels':  _infrastructureLevels,
      'marketingLevels':       _marketingLevels,
      'leagueStandings': {
        for (final e in _leagueStandings.entries)
          e.key: e.value.map((r) => r.toMap()).toList(),
      },
      'facilityNamingSold': _facilityNamingSold,
      'facilityNamingLabels': {
        for (final e in _facilityNamingLabel.entries)
          if (e.value != null) e.key: e.value,
      },
      // Kupa durumu
      'branchCupRound': {
        for (final e in _branchCupRound.entries)
          e.key: e.value?.name,
      },
      'branchCupFarthest': {
        for (final e in _branchCupFarthest.entries)
          e.key: e.value?.name,
      },
      // Sponsorlar — sadece aktif sponsorları kaydet
      'activeSponsors': {
        for (final e in _activeSponsors.entries)
          if (e.value != null) e.key: _activeSponsorToMap(e.value!),
      },
      'namingRightsSeasons': _namingRightsSeasons,
      'needsSponsorSelection': _needsSponsorSelection,
      'trophyRoom': _trophyRoom.map((t) => t.toMap()).toList(),
      'fixturePlans': _fixturePlansToJson(),
      'matchHistory': _matchHistory.map((m) => m.toMap()).toList(),
      'moraleFixture': Map<String, int>.from(_branchMoraleNextFixture),
      'presEvAccum': _weeksAccumulatedPresident,
      'presEvGap': _presidentNextGapWeeks,
      'pendingPresidentId': _pendingRandomPresidentEvent?.id,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSaveKey, jsonEncode(data));
  }

  Map<String, dynamic> _fixturePlansToJson() {
    return {
      for (final e in _seasonFixturePlans.entries)
        e.key: [
          for (final round in e.value)
            [
              for (final p in round) {'h': p.$1, 'a': p.$2},
            ],
        ],
    };
  }

  void _fixturePlansFromJson(dynamic raw) {
    _seasonFixturePlans.clear();
    if (raw == null || raw is! Map) return;
    final mp = Map<String, dynamic>.from(raw as Map);
    for (final e in mp.entries) {
      final branch = e.key as String;
      final rounds = <List<(String, String)>>[];
      if (e.value is! List) continue;
      for (final r in e.value as List<dynamic>) {
        if (r is! List) continue;
        final pairs = <(String, String)>[];
        for (final item in r) {
          if (item is! Map<String, dynamic>) continue;
          final h = item['h'] as String?;
          final a = item['a'] as String?;
          if (h != null && a != null) pairs.add((h, a));
        }
        rounds.add(pairs);
      }
      _seasonFixturePlans[branch] = rounds;
    }
  }

  RandomEvent? _randomEventFromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final ev in presidentRandomCatalog) {
      if (ev.id == id) return ev;
    }
    return null;
  }

  /// Kaydedilmiş oyunu yükler. `true` dönerse oyun kurtarıldı; `false` ise kayıt yok.
  Future<bool> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kSaveKey);
      if (raw == null) return false;

      final data = jsonDecode(raw) as Map<String, dynamic>;

      _currentClub      = Club.fromMap(data['club'] as Map<String, dynamic>);
      _currentPresident =
          President.fromMap(data['president'] as Map<String, dynamic>);
      _currentWeek    = data['currentWeek'] as int;
      _seasonNumber   = data['seasonNumber'] as int;
      _calendarYear   =
          (data['calendarYear'] as int?) ??
          (museumCalendarBaseYear + _seasonNumber - 1);

      _mapFromJson(data['branchLeagueIndices'],  _branchLeagueIndices,  (v) => v as int);
      _mapFromJson(data['branchPoints'],         _branchPoints,         (v) => v as int);
      _mapFromJson(data['facilityLevels'],       _facilityLevels,       (v) => v as int);
      _mapFromJson(data['infrastructureLevels'], _infrastructureLevels, (v) => v as int);
      _mapFromJson(data['marketingLevels'],      _marketingLevels,      (v) => v as int);

      _trophyRoom.clear();
      final rawTrophies = data['trophyRoom'] as List<dynamic>? ?? [];
      for (final raw in rawTrophies) {
        _trophyRoom.add(Trophy.fromMap(
          Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
        ));
      }

      _leagueStandings.clear();
      final standingsRaw = data['leagueStandings'] as Map<String, dynamic>?;
      if (standingsRaw != null) {
        for (final e in standingsRaw.entries) {
          final rawList = e.value as List<dynamic>? ?? [];
          _leagueStandings[e.key] = rawList
              .map((m) => LeagueStandingEntry.fromMap(
                    Map<String, dynamic>.from(m as Map<dynamic, dynamic>),
                  ))
              .toList();
        }
      }

      if (data['facilityNamingSold'] != null) {
        _mapFromJson(
          data['facilityNamingSold'] as Map<String, dynamic>,
          _facilityNamingSold,
          (v) => v as bool,
        );
      }
      _facilityNamingLabel.updateAll((k, v) => null);
      final fnl = data['facilityNamingLabels'] as Map<String, dynamic>? ?? {};
      for (final e in fnl.entries) {
        _facilityNamingLabel[e.key] = e.value as String?;
      }

      _ensureLeagueStandingsLoaded();

      // Kupa durumu
      final cupRoundMap    = data['branchCupRound']    as Map<String, dynamic>? ?? {};
      final cupFarthestMap = data['branchCupFarthest'] as Map<String, dynamic>? ?? {};
      for (final b in [CountryData.football, CountryData.basketball, CountryData.volleyball]) {
        final rName = cupRoundMap[b] as String?;
        _branchCupRound[b] = rName == null
            ? null
            : CupRound.values.firstWhere((r) => r.name == rName,
                orElse: () => CupRound.r1);
        final fName = cupFarthestMap[b] as String?;
        if (fName != null) {
          _branchCupFarthest[b] = CupRound.values.firstWhere(
              (r) => r.name == fName,
              orElse: () => CupRound.r1);
        }
      }

      // Aktif sponsorlar
      _activeSponsors.clear();
      final sponsorMap = data['activeSponsors'] as Map<String, dynamic>? ?? {};
      for (final e in sponsorMap.entries) {
        _activeSponsors[e.key] =
            _activeSponsorFromMap(e.value as Map<String, dynamic>);
      }

      // Naming rights
      _namingRightsSeasons.clear();
      final nrMap = data['namingRightsSeasons'] as Map<String, dynamic>? ?? {};
      for (final e in nrMap.entries) {
        _namingRightsSeasons[e.key] = e.value as int;
      }

      _needsSponsorSelection =
          data['needsSponsorSelection'] as bool? ?? false;

      _fixturePlansFromJson(data['fixturePlans']);
      _invalidateLeagueCalendarMemo();
      final hasFx = _seasonFixturePlans.values.any((lst) => lst.isNotEmpty);
      if (!hasFx) {
        _regenerateSeasonFixturePlans();
      }

      _matchHistory.clear();
      for (final mh in data['matchHistory'] as List<dynamic>? ?? []) {
        _matchHistory.add(MatchResult.fromMap(
          Map<String, dynamic>.from(mh as Map<dynamic, dynamic>),
        ));
      }

      _branchMoraleNextFixture.clear();
      final morFx = data['moraleFixture'] as Map<String, dynamic>? ?? {};
      for (final e in morFx.entries) {
        _branchMoraleNextFixture[e.key] = (e.value as num).round();
      }

      _weeksAccumulatedPresident = data['presEvAccum'] as int? ?? 0;
      _presidentNextGapWeeks =
          data['presEvGap'] as int? ?? (3 + _rng.nextInt(2));
      _pendingRandomPresidentEvent =
          _randomEventFromId(data['pendingPresidentId'] as String?);

      // Geçici state temizle (yüklemede haftalık rapor yok)
      _lastSeasonResults  = null;
      _lastWeekResults    = [];
      _lastEconomySummary = null;
      _lastCupResults     = [];
      _pendingSponsorOffers.clear();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('GameProvider.loadGame hata: $e');
      return false;
    }
  }

  /// Kaydı siler ve oyunu sıfırlar.
  Future<void> clearSaveAndReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSaveKey);
    resetGame();
  }

  /// Dev / test: SharedPreferences içindeki **tüm** anahtarları siler ve state sıfırlanır.
  Future<void> wipeAllSharedPreferencesAndReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    resetGame();
    notifyListeners();
  }

  /// Kaydedilmiş oyun var mı kontrol eder (GameProvider'ı değiştirmez).
  static Future<bool> hasSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kSaveKey);
  }

  // Kayıt yardımcıları ---------------------------------------------------------

  void _mapFromJson<T>(
    dynamic raw,
    Map<String, T> target,
    T Function(dynamic) convert,
  ) {
    if (raw == null) return;
    final map = raw as Map<String, dynamic>;
    for (final e in map.entries) {
      target[e.key] = convert(e.value);
    }
  }

  Map<String, dynamic> _activeSponsorToMap(ActiveSponsor s) => {
    'offer': {
      'id':              s.offer.id,
      'sponsorName':     s.offer.sponsorName,
      'branch':          s.offer.branch,
      'sector':          s.offer.sector,
      'type':            s.offer.type.name,
      'upfrontPayment':  s.offer.upfrontPayment,
      'winBonus':        s.offer.winBonus,
      'reputationBonus': s.offer.reputationBonus,
      'description':     s.offer.description,
      'pointTarget':     s.offer.pointTarget,
      'penaltyFactor':   s.offer.penaltyFactor,
      'isNamingRights':  s.offer.isNamingRights,
      'contractSeasons': s.offer.contractSeasons,
      if (s.offer.brandTier != null) 'brandTier': s.offer.brandTier!.name,
    },
    'seasonWins':               s.seasonWins,
    'remainingContractSeasons': s.remainingContractSeasons,
  };

  ActiveSponsor _activeSponsorFromMap(Map<String, dynamic> m) {
    final om = m['offer'] as Map<String, dynamic>;
    final offer = SponsorOffer(
      id:              om['id'] as String,
      sponsorName:     om['sponsorName'] as String,
      branch:          om['branch'] as String,
      sector:          om['sector'] as String? ?? 'Genel',
      type:            SponsorType.values
          .firstWhere((t) => t.name == om['type'] as String),
      upfrontPayment:  (om['upfrontPayment'] as num).toDouble(),
      winBonus:        (om['winBonus'] as num).toDouble(),
      reputationBonus: om['reputationBonus'] as int? ?? 0,
      description:     om['description'] as String? ?? '',
      pointTarget:     om['pointTarget'] != null
          ? (om['pointTarget'] as num).toInt()
          : null,
      penaltyFactor:   (om['penaltyFactor'] as num).toDouble(),
      isNamingRights:  om['isNamingRights'] as bool? ?? false,
      contractSeasons: om['contractSeasons'] as int?,
      brandTier: switch (om['brandTier'] as String?) {
        'elite' => SponsorBrandTier.elite,
        'pro' => SponsorBrandTier.pro,
        'local' => SponsorBrandTier.local,
        _ => null,
      },
    );
    final sponsor = ActiveSponsor(offer: offer);
    sponsor.seasonWins               = m['seasonWins'] as int? ?? 0;
    sponsor.remainingContractSeasons =
        m['remainingContractSeasons'] as int? ?? 1;
    return sponsor;
  }

  // ── Yardımcı ───────────────────────────────────────────────────────────────

  int _weeklyPoints(double successRate) {
    final roll = _rng.nextDouble();
    if (roll < successRate * 0.65) return 3;
    if (roll < successRate * 0.65 + 0.18) return 1;
    return 0;
  }

  List<Branch> _buildBranches({
    Map<String, double>? budgets,
    int reputation = 50,
  }) {
    const amateurFanPenalty = 0.4;
    const branchNames = [
      CountryData.football, CountryData.basketball, CountryData.volleyball,
    ];
    final repSrBonus = reputation.clamp(0, 100) / 2000.0;
    return branchNames.map((name) {
      final budget     = budgets?[name] ?? _defaultBudgetFor(name);
      final levelIndex = _branchLeagueIndices[name] ?? 0;
      final infraLvl   = _infrastructureLevels[name] ?? 0;
      final infraBonus =
          InvestmentCatalog.infrastructureSuccessBonus(infraLvl, levelIndex);
      final successRate = (BranchLeagueData.calcSuccessRate(
        branch: name,
        budget: budget,
        levelIndex: levelIndex,
        infrastructureLevel: 0,
      ) +
              infraBonus +
              repSrBonus)
          .clamp(0.0, 1.0);
      final fanInterest =
          (50 * CountryData.multiplierFor(name) * amateurFanPenalty)
              .round()
              .clamp(0, 100);
      return Branch(
          name: name, budget: budget, successRate: successRate,
          fanInterest: fanInterest, trophyCount: 0);
    }).toList();
  }

  void _recalcBranchSuccessRate(String branchName) {
    final club = _currentClub;
    if (club == null) return;
    final updated = club.branches.map((b) {
      if (b.name != branchName) return b;
      final leagueIdx = _branchLeagueIndices[b.name] ?? 0;
      final infraLvl  = _infrastructureLevels[b.name] ?? 0;
      final infraBonus = InvestmentCatalog.infrastructureSuccessBonus(
          infraLvl, leagueIdx);
      final repSr = _clubSuccessRateReputationBonus(reputation: club.reputation);
      final newRate = BranchLeagueData.calcSuccessRate(
            branch: b.name,
            budget: b.budget,
            levelIndex: leagueIdx,
            fanInterest: b.fanInterest,
            infrastructureLevel: 0, // bonus dışarıdan ekleniyor
          ) +
          infraBonus +
          repSr;
      return b.copyWith(successRate: newRate.clamp(0.0, 1.0));
    }).toList();
    _currentClub = club.copyWith(branches: updated);
  }

  double _defaultBudgetFor(String branchName) => switch (branchName) {
        CountryData.football   => 250000,
        CountryData.basketball => 150000,
        CountryData.volleyball => 100000,
        _                      => 100000,
      };

  // ── Türkiye Kupası Sistemi ─────────────────────────────────────────────────

  /// Kupa maçı haftasındaki tüm branşlar için maçları simüle eder.
  List<CupMatchResult> _playCupMatchesThisWeek(List<Branch> currentBranches) {
    final results = <CupMatchResult>[];
    for (final branch in [
      CountryData.football, CountryData.basketball, CountryData.volleyball,
    ]) {
      final round = _branchCupRound[branch];
      if (round == null || round == CupRound.champion) continue;

      final branchData =
          currentBranches.firstWhere((b) => b.name == branch,
              orElse: () => Branch(
                  name: branch, budget: _defaultBudgetFor(branch),
                  successRate: 0.3, fanInterest: 50, trophyCount: 0));

      final result = _simulateCupMatch(branch, round, branchData);
      results.add(result);
    }
    return results;
  }

  /// Tek bir kupa maçını simüle eder.
  CupMatchResult _simulateCupMatch(
      String branch, CupRound round, Branch branchData) {
    final myLeagueLevel  = _branchLeagueIndices[branch] ?? 0;
    final maxLeagues     = BranchLeagueData.leagueCount(branch);
    // Rakip ligin seviyesi: tüm liglerden herhangi biri (kupa herkese açık)
    final opponentLevel  = _rng.nextInt(maxLeagues);
    final opponentLeague = BranchLeagueData.leagueName(branch, opponentLevel);
    final isUpset        = opponentLevel > myLeagueLevel;

    // Kupa zorluğu: rakip lig seviyesine göre, üst ligdeyse +%20
    var difficulty = BranchLeagueData.difficultyAt(branch, opponentLevel);
    if (isUpset) difficulty *= 1.2;

    final repCupBonus =
        ((_currentClub?.reputation ?? 0).clamp(0, 100)) / 2000.0;
    // SuccessRate: kendi bütçe/fan/infra + itibar küçük bonus
    final successRate = ((branchData.budget *
                    (BranchLeagueData.budgetImpactMultipliers[branch] ?? 1.0) /
                    difficulty *
                    (0.8 + branchData.fanInterest * 0.004) *
                    (1.0 + (_infrastructureLevels[branch] ?? 0) * 0.05)) +
                repCupBonus)
            .clamp(0.08, 0.92);

    final advanced = _rng.nextDouble() < successRate;

    double prize = 0;
    if (advanced) {
      prize = round.basePrize * (1 + myLeagueLevel * 0.5);
      _branchCupFarthest[branch] = round;  // bu turu kazandı
      _branchCupRound[branch] = round.next; // ilerle
    } else {
      _branchCupRound[branch] = null; // elendi
    }

    return CupMatchResult(
      branch: branch,
      round: round,
      advanced: advanced,
      opponentLeague: opponentLeague,
      opponentWasHigherLeague: isUpset,
      prizeEarned: prize,
    );
  }

  /// Sezon sonu kupa ilerleme etiketi.
  String _buildCupLabel(String branch) {
    final current  = _branchCupRound[branch];
    final farthest = _branchCupFarthest[branch];

    if (current == CupRound.champion) return '🏆 Kupa Şampiyonu!';
    if (farthest == null)             return '1. Turda Elendi';
    // Son kazanılan turdan bir sonrakinde elendi
    final eliminatedAt = farthest.next;
    if (eliminatedAt == null)         return '🏆 Kupa Şampiyonu!';
    return '${eliminatedAt.label}\'de Elendi';
  }

  // ── Sponsor Teklifi Üreteci ────────────────────────────────────────────────

  // ── Gerçek Sponsor Kütüphanesi ──────────────────────────────────────────────

  static const List<(String name, String sector, SponsorBrandTier tier)> _realSponsorBrands =
      [
    ('Türk Hava Yolları', 'Ulaşım', SponsorBrandTier.elite),
    ('Pegasus', 'Ulaşım', SponsorBrandTier.pro),
    ('Socar', 'Enerji', SponsorBrandTier.elite),
    ('Tüpraş', 'Enerji', SponsorBrandTier.elite),
    ('Uludağ İçecek', 'İçecek', SponsorBrandTier.local),
    ('Getir', 'Lojistik & Teknoloji', SponsorBrandTier.pro),
    ('Trendyol', 'E-Ticaret', SponsorBrandTier.pro),
    ('Yemeksepeti', 'E-Ticaret', SponsorBrandTier.local),
    ('Turkcell', 'Telekomünikasyon', SponsorBrandTier.elite),
    ('İş Bankası', 'Finans', SponsorBrandTier.elite),
    ('Ziraat Bankası', 'Finans', SponsorBrandTier.elite),
  ];

  int _fanInterestForBranch(String branch) {
    final club = _currentClub;
    if (club == null) return 50;
    for (final b in club.branches) {
      if (b.name == branch) return b.fanInterest;
    }
    return 50;
  }

  /// Taraftar ilgisi yüksekse havuz büyük markaları da içerir; seçim rasgeledir.
  /// [reputation] ≤ 70 iken Elite markalar çıkarılır (THY, Socar, vb.).
  (String, String, SponsorBrandTier) _pickRealSponsorBrand(int popularity,
      {required int reputation}) {
    final n = _realSponsorBrands.length;
    final p = popularity.clamp(0, 100);
    final poolEnd = max(3, (3 + (p / 100) * (n - 3)).ceil());
    final slice = _realSponsorBrands.sublist(0, poolEnd);
    var eligible = slice
        .where((e) =>
            e.$3 != SponsorBrandTier.elite || reputation > 70)
        .toList();
    if (eligible.isEmpty) {
      eligible = slice
          .where((e) => e.$3 != SponsorBrandTier.elite)
          .toList();
    }
    if (eligible.isEmpty) {
      eligible = _realSponsorBrands
          .where((e) => e.$3 != SponsorBrandTier.elite)
          .toList();
    }
    if (eligible.isEmpty) eligible = slice;
    final pick = eligible[_rng.nextInt(eligible.length)];
    return (pick.$1, pick.$2, pick.$3);
  }

  double _dominantSponsorEuroBase(String branch, int leagueLevelIndex0) {
    final tierL = (leagueLevelIndex0 + 1).clamp(1, 22);
    const anchor = 2050.0;
    final norm = switch (branch) {
      CountryData.football => 1.0,
      CountryData.basketball => 0.6,
      CountryData.volleyball => 0.4,
      _ => 0.55,
    };
    final dominantPow = pow(tierL.toDouble(), 3.85);
    return anchor * dominantPow * norm;
  }

  void _generateSponsorOffers() {
    _pendingSponsorOffers.clear();
    for (final branch in [
      CountryData.football, CountryData.basketball, CountryData.volleyball,
    ]) {
      // Aktif naming rights sözleşmesi varsa bu branş için teklif üretme
      if ((_namingRightsSeasons[branch] ?? 0) > 0) continue;

      final level = _branchLeagueIndices[branch] ?? 0;
      _pendingSponsorOffers[branch] = _offersForBranch(branch, level);
    }
  }

  List<SponsorOffer> _offersForBranch(String branch, int leagueLevel) {
    final club = _currentClub;
    if (club == null) return [];

    final base = _dominantSponsorEuroBase(branch, leagueLevel).clamp(
      800.0,
      990000000.0,
    );
    final mult = sponsorMuseumCashMultiplier;
    final ts = DateTime.now().millisecondsSinceEpoch;

    final rep = club.reputation;
    final pop = _fanInterestForBranch(branch);
    final (nameA, sectorA, tierA) =
        _pickRealSponsorBrand((pop + 6).clamp(0, 100), reputation: rep);
    final (nameB, sectorB, tierB) =
        _pickRealSponsorBrand((pop + 20).clamp(0, 100), reputation: rep);
    final (nameC, sectorC, tierC) =
        _pickRealSponsorBrand((pop + 35).clamp(0, 100), reputation: rep);

    // Garanti sponsorlar yüksek ligde fesih şartı taşıyabilir
    final hasClause = leagueLevel >= 1;
    final maxSeasonPts = BranchLeagueData.leagueMatchWeeksInSeason(branch) * 3;
    final targetPts =
        (maxSeasonPts * 0.52).round().clamp(20, 200) + leagueLevel * 3;

    final offers = <SponsorOffer>[
      SponsorOffer(
        id: '${branch}_A_$ts',
        sponsorName: nameA, branch: branch,
        type: SponsorType.guaranteed, sector: sectorA,
        brandTier: tierA,
        upfrontPayment: (base * 2.0 * mult).roundToDouble(),
        winBonus:       (base * 0.02 * mult).roundToDouble(),
        reputationBonus: 0,
        description: 'Yüksek peşinat garantisi. Galibiyet primleri düşük '
            'ama kasana hemen büyük katkı sağlar.',
        pointTarget:    hasClause ? targetPts : null,
        penaltyFactor:  0.5,
      ),
      SponsorOffer(
        id: '${branch}_B_$ts',
        sponsorName: nameB, branch: branch,
        type: SponsorType.performance, sector: sectorB,
        brandTier: tierB,
        upfrontPayment: (base * 0.3 * mult).roundToDouble(),
        winBonus:       (base * 0.15 * mult).roundToDouble(),
        reputationBonus: 0,
        description: 'Düşük peşinat; her galibiyet sonrası yüksek prim. '
            'Performanslı takımlar için ideal.',
      ),
      SponsorOffer(
        id: '${branch}_C_$ts',
        sponsorName: nameC, branch: branch,
        type: SponsorType.prestige, sector: sectorC,
        brandTier: tierC,
        upfrontPayment: (base * 1.0 * mult).roundToDouble(),
        winBonus:       (base * 0.05 * mult).roundToDouble(),
        reputationBonus: 5 + leagueLevel * 2,
        description: 'Orta peşinat ve kulüp itibarına kalıcı katkı. '
            'Uzun vadeli marka değeri inşa etmek isteyenler için.',
      ),
    ];

    // Stat isim hakkı: Lig index ≥ 2 (3. Lig ve üstü) iken açılır
    if (leagueLevel >= 2) {
      final (nameNR, sectorNR, tierNR) =
          _pickRealSponsorBrand(max(pop + 45, 60).clamp(0, 100),
              reputation: rep);
      final namingLabel = '$nameNR Park';

      offers.add(SponsorOffer(
        id: '${branch}_NR_$ts',
        sponsorName: namingLabel,
        branch: branch,
        type: SponsorType.namingRights,
        sector: sectorNR,
        brandTier: tierNR,
        upfrontPayment: (base * 8.0 * mult).roundToDouble(),
        winBonus: 0,
        reputationBonus: 10 + leagueLevel * 3,
        description: 'Stadyumunuz bu markanın adını taşıyacak. '
            'Devasa nakit girişi ama 3 sezonluk bağlayıcı anlaşma.',
        isNamingRights: true,
        contractSeasons: 3,
      ));
    }

    return offers;
  }
}
