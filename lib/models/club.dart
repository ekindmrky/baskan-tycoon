import 'branch.dart';

class Club {
  final String name;
  final String city;
  final String primaryColor;
  final String secondaryColor;
  final double treasury;
  final double debt;
  final int reputation;
  final List<Branch> branches;

  const Club({
    required this.name,
    required this.city,
    required this.primaryColor,
    required this.secondaryColor,
    this.treasury = 0,
    this.debt = 0,
    this.reputation = 50,
    this.branches = const [],
  });

  // --- Finansal getter'lar ---

  /// Kasa eksi borç: kulübün net serveti.
  double get totalWealth => treasury - debt;

  /// Borç/kasa oranı. 1.0 üzeri kritik bölge.
  double get debtRatio => treasury > 0 ? debt / treasury : double.infinity;

  /// Tüm branşların toplam bütçesi.
  double get totalBranchBudget =>
      branches.fold(0, (sum, b) => sum + b.budget);

  /// Kasa dışında hâlâ kullanılabilir özgür nakit.
  double get freeCash => treasury - totalBranchBudget;

  bool get isFinanciallyHealthy => totalWealth > 0 && debtRatio < 0.5;

  // --- İtibar / branş getter'ları ---

  /// Tüm branşlardaki toplam kupa sayısı.
  int get totalTrophies =>
      branches.fold(0, (sum, b) => sum + b.trophyCount);

  /// Tüm branşlardaki ortalama başarı oranı.
  double get averageSuccessRate => branches.isEmpty
      ? 0
      : branches.fold(0.0, (sum, b) => sum + b.successRate) / branches.length;

  /// Ortalama taraftar ilgisi (0–100).
  double get averageFanInterest => branches.isEmpty
      ? 0
      : branches.fold(0.0, (sum, b) => sum + b.fanInterest) / branches.length;

  // --- copyWith ---

  Club copyWith({
    String? name,
    String? city,
    String? primaryColor,
    String? secondaryColor,
    double? treasury,
    double? debt,
    int? reputation,
    List<Branch>? branches,
  }) {
    return Club(
      name: name ?? this.name,
      city: city ?? this.city,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      treasury: treasury ?? this.treasury,
      debt: debt ?? this.debt,
      reputation: reputation ?? this.reputation,
      branches: branches ?? this.branches,
    );
  }

  // --- Serialization ---

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'city': city,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'treasury': treasury,
      'debt': debt,
      'reputation': reputation,
      'branches': branches.map((b) => b.toMap()).toList(),
    };
  }

  factory Club.fromMap(Map<String, dynamic> map) {
    final rawBranches = map['branches'];
    final branches = <Branch>[];
    if (rawBranches is List) {
      for (final b in rawBranches) {
        if (b is Map<String, dynamic>) {
          try {
            branches.add(Branch.fromMap(b));
          } catch (_) {
            // atla
          }
        }
      }
    }

    return Club(
      name: map['name'] as String? ?? '',
      city: map['city'] as String? ?? '',
      primaryColor: map['primaryColor'] as String? ?? '#1565C0',
      secondaryColor: map['secondaryColor'] as String? ?? '#FFBF00',
      treasury: (map['treasury'] as num?)?.toDouble() ?? 0,
      debt: (map['debt'] as num?)?.toDouble() ?? 0,
      reputation: map['reputation'] as int? ?? 50,
      branches: branches,
    );
  }

  @override
  String toString() =>
      'Club(name: $name, city: $city, treasury: $treasury, debt: $debt, '
      'reputation: $reputation, branches: ${branches.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Club &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          city == other.city &&
          primaryColor == other.primaryColor &&
          secondaryColor == other.secondaryColor &&
          treasury == other.treasury &&
          debt == other.debt &&
          reputation == other.reputation;

  @override
  int get hashCode => Object.hash(
        name,
        city,
        primaryColor,
        secondaryColor,
        treasury,
        debt,
        reputation,
      );
}
