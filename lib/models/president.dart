class President {
  final String name;
  final int age;
  final double personalReputation;
  final int charisma;

  const President({
    required this.name,
    required this.age,
    this.personalReputation = 0.5,
    this.charisma = 50,
  });

  // --- Hesaplanmış getter'lar ---

  /// Genel etki puanı: karizmanın itibarla ağırlıklı ortalaması.
  double get influenceScore =>
      (charisma / 100.0) * 0.6 + personalReputation * 0.4;

  /// Tecrübe katsayısı: 35 yaş üzeri artar, 65 yaşta zirveye ulaşır.
  double get experienceFactor {
    if (age < 30) return 0.6;
    if (age < 45) return 0.6 + (age - 30) * 0.02;
    if (age < 65) return 0.9 + (age - 45) * 0.005;
    return 1.0;
  }

  bool get isVeteran => age >= 50 && personalReputation >= 0.7;

  // --- copyWith ---

  President copyWith({
    String? name,
    int? age,
    double? personalReputation,
    int? charisma,
  }) {
    return President(
      name: name ?? this.name,
      age: age ?? this.age,
      personalReputation: personalReputation ?? this.personalReputation,
      charisma: charisma ?? this.charisma,
    );
  }

  // --- Serialization ---

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'personalReputation': personalReputation,
      'charisma': charisma,
    };
  }

  factory President.fromMap(Map<String, dynamic> map) {
    return President(
      name: map['name'] as String,
      age: map['age'] as int,
      personalReputation: (map['personalReputation'] as num).toDouble(),
      charisma: map['charisma'] as int,
    );
  }

  @override
  String toString() =>
      'President(name: $name, age: $age, personalReputation: $personalReputation, '
      'charisma: $charisma)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is President &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          age == other.age &&
          personalReputation == other.personalReputation &&
          charisma == other.charisma;

  @override
  int get hashCode => Object.hash(name, age, personalReputation, charisma);
}
