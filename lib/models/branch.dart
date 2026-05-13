class Branch {
  final String name;
  final double budget;
  final double successRate;
  final int fanInterest;
  final int trophyCount;

  const Branch({
    required this.name,
    required this.budget,
    this.successRate = 0.5,
    this.fanInterest = 50,
    this.trophyCount = 0,
  });

  double get budgetEfficiency => budget > 0 ? successRate / (budget / 1000000) : 0;

  bool get isElite => trophyCount >= 5 && successRate >= 0.7;

  Branch copyWith({
    String? name,
    double? budget,
    double? successRate,
    int? fanInterest,
    int? trophyCount,
  }) {
    return Branch(
      name: name ?? this.name,
      budget: budget ?? this.budget,
      successRate: successRate ?? this.successRate,
      fanInterest: fanInterest ?? this.fanInterest,
      trophyCount: trophyCount ?? this.trophyCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'budget': budget,
      'successRate': successRate,
      'fanInterest': fanInterest,
      'trophyCount': trophyCount,
    };
  }

  factory Branch.fromMap(Map<String, dynamic> map) {
    return Branch(
      name: map['name'] as String,
      budget: (map['budget'] as num).toDouble(),
      successRate: (map['successRate'] as num).toDouble(),
      fanInterest: map['fanInterest'] as int,
      trophyCount: map['trophyCount'] as int,
    );
  }

  @override
  String toString() =>
      'Branch(name: $name, budget: $budget, successRate: $successRate, '
      'fanInterest: $fanInterest, trophyCount: $trophyCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Branch &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          budget == other.budget &&
          successRate == other.successRate &&
          fanInterest == other.fanInterest &&
          trophyCount == other.trophyCount;

  @override
  int get hashCode => Object.hash(name, budget, successRate, fanInterest, trophyCount);
}
