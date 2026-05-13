
enum RandomEventKind {
  sponsorship,
  bonusDistribution,
  scandal,
  citySupport,
  youngTalent,
  fanBoycott,
  mediaAttention,
  rivalryHype,
  infrastructureIssue,
  sponsorCrisis,
}

class RandomEventOption {
  final String label;
  final String description;
  final double treasuryDelta;
  final int fanInterestDelta;
  final int reputationDelta;
  final String? targetBranch;
  /// Bir sonraki lig maçında oyuncunun haftalık formuna tek seferlik ek (+ / −).
  final int moraleFormDelta;
  final String? moraleTargetBranch;

  const RandomEventOption({
    required this.label,
    required this.description,
    this.treasuryDelta = 0,
    this.fanInterestDelta = 0,
    this.reputationDelta = 0,
    this.targetBranch,
    this.moraleFormDelta = 0,
    this.moraleTargetBranch,
  });
}

/// Başkanlık / kulüp kararı — A/B seçenekleri.
class RandomEvent {
  final String id;
  final RandomEventKind kind;
  final String title;
  final String narrative;
  final RandomEventOption optionA;
  final RandomEventOption optionB;

  const RandomEvent({
    required this.id,
    required this.kind,
    required this.title,
    required this.narrative,
    required this.optionA,
    required this.optionB,
  });

  RandomEventOption chosen(bool pickFirst) =>
      pickFirst ? optionA : optionB;

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'narrative': narrative,
        'optionA': _optToMap(optionA),
        'optionB': _optToMap(optionB),
      };

  static Map<String, dynamic> _optToMap(RandomEventOption o) => {
        'label': o.label,
        'description': o.description,
        'treasuryDelta': o.treasuryDelta,
        'fanInterestDelta': o.fanInterestDelta,
        'reputationDelta': o.reputationDelta,
        'targetBranch': o.targetBranch,
        'moraleFormDelta': o.moraleFormDelta,
        'moraleTargetBranch': o.moraleTargetBranch,
      };

  factory RandomEvent.fromMap(Map<String, dynamic> m) {
    RandomEventKind kd = RandomEventKind.sponsorship;
    final ks = m['kind'] as String?;
    if (ks != null) {
      kd = RandomEventKind.values
          .firstWhere((v) => v.name == ks, orElse: () => kd);
    }
    return RandomEvent(
      id: m['id'] as String,
      kind: kd,
      title: m['title'] as String,
      narrative: m['narrative'] as String,
      optionA: _optFromMap(m['optionA'] as Map<String, dynamic>),
      optionB: _optFromMap(m['optionB'] as Map<String, dynamic>),
    );
  }

  static RandomEventOption _optFromMap(Map<String, dynamic> om) =>
      RandomEventOption(
        label: om['label'] as String,
        description: om['description'] as String,
        treasuryDelta: (om['treasuryDelta'] as num?)?.toDouble() ?? 0,
        fanInterestDelta: om['fanInterestDelta'] as int? ?? 0,
        reputationDelta: om['reputationDelta'] as int? ?? 0,
        targetBranch: om['targetBranch'] as String?,
        moraleFormDelta: om['moraleFormDelta'] as int? ?? 0,
        moraleTargetBranch: om['moraleTargetBranch'] as String?,
      );
}

const List<RandomEvent> presidentRandomCatalog = [
  RandomEvent(
    id: 'reklam_paneli',
    kind: RandomEventKind.sponsorship,
    title: 'Reklam Panosu Teklifi',
    narrative:
        'Yerel bir büyük marka stadyumunuza reklam panosu yerleştirmek istiyor. '
        'Para cazip ama bazı taraftarlar formanın ticarileşmesinden şikayet ediyor.',
    optionA: RandomEventOption(
      label: 'Kabul Et',
      description:
          '+60.000 €, taraftar ilgisi -5 · Moral: odak kaybı (form -1)',
      treasuryDelta: 60000,
      fanInterestDelta: -5,
      moraleFormDelta: -1,
    ),
    optionB: RandomEventOption(
      label: 'Reddet',
      description: 'Taraftarlar memnun, itibar +4 · Takım daha disiplinli (form +1)',
      reputationDelta: 4,
      moraleFormDelta: 1,
    ),
  ),
  RandomEvent(
    id: 'oyuncu_prim',
    kind: RandomEventKind.bonusDistribution,
    title: 'Oyuncu Prim Talebi',
    narrative:
        'Kafile sezon içi başarı için prim talep ediyor. Ödersen bağlılık artar.'
        ' Eskitirsen yüz yüze geldikleri haftalık daha gergin geçebilir.',
    optionA: RandomEventOption(
      label: 'Prim Öde',
      description: '-30.000 €, taraftar ilgisi +8 · Moral +3 (tüm branşlar)',
      treasuryDelta: -30000,
      fanInterestDelta: 8,
      moraleFormDelta: 3,
    ),
    optionB: RandomEventOption(
      label: 'Ertele',
      description: 'Kasa korunur, taraftar ilgisi -6 · Moral -2',
      fanInterestDelta: -6,
      moraleFormDelta: -2,
    ),
  ),
  RandomEvent(
    id: 'belediye_ortak',
    kind: RandomEventKind.citySupport,
    title: 'Belediye Ortaklığı',
    narrative:
        'Şehir belediyesi altyapı için ortak proje teklif ediyor. Onay güven verir.'
        ' Bazı oyuncular bürokrasiden sıkılıyor.',
    optionA: RandomEventOption(
      label: 'Kabul Et',
      description: '+45.000 €, itibar +3 · Moral +2',
      treasuryDelta: 45000,
      reputationDelta: 3,
      moraleFormDelta: 2,
    ),
    optionB: RandomEventOption(
      label: 'Bağımsız Kal',
      description:
          'Taraftar özerklik hisseder (+6) ancak oyuncular destek özlemi hisseder (−2 moral)',
      fanInterestDelta: 6,
      moraleFormDelta: -2,
    ),
  ),
  RandomEvent(
    id: 'tv_programi',
    kind: RandomEventKind.mediaAttention,
    title: 'TV Programı Daveti',
    narrative:
        'Ünlü bir spor programında kulübünüz için panel isteniyor. Medya yüzünü güçlendirir.'
        ' Haftanın kalanında dikkat dağılabilir.',
    optionA: RandomEventOption(
      label: 'Kabul Et',
      description:
          '+20.000 €, itibar +5 · Moral -1 (fazla kamera arkası)'
          '',
      treasuryDelta: 20000,
      reputationDelta: 5,
      moraleFormDelta: -1,
    ),
    optionB: RandomEventOption(
      label: 'Odağı Koru',
      description:
          'Taraftar ilgisi +10, para yok · Moral +3 (kamp odak)',
      fanInterestDelta: 10,
      moraleFormDelta: 3,
    ),
  ),
  RandomEvent(
    id: 'derbi_kamp',
    kind: RandomEventKind.rivalryHype,
    title: 'Derbi Kampı Tartışması',
    narrative:
        'Derbi öncesi özel kamp masraflı ama taraftar coşkunluk bekliyor. '
        'Görünürlük yüksek; takım tepkisi seçimine bağlı.',
    optionA: RandomEventOption(
      label: 'Kampı Onayla',
      description:
          '-20.000 €, taraftar +12 · Moral +4 (kamp ateşlemesi)'
          '',
      treasuryDelta: -20000,
      fanInterestDelta: 12,
      moraleFormDelta: 4,
    ),
    optionB: RandomEventOption(
      label: 'Normal Hazırlık',
      description:
          'Kasa korunur · Moral -1',
      moraleFormDelta: -1,
    ),
  ),
  RandomEvent(
    id: 'basin_krizi',
    kind: RandomEventKind.scandal,
    title: 'Basın Krizi',
    narrative:
        'Oyuncunun paylaşımı gündem oldu. Kulüpten çıkış mı gelecek?',
    optionA: RandomEventOption(
      label: 'Resmi Açıklama',
      description:
          '-10.000 €, itibar -2, taraftar +5 · Moral düzen (+2)'
          '',
      treasuryDelta: -10000,
      reputationDelta: -2,
      fanInterestDelta: 5,
      moraleFormDelta: 2,
    ),
    optionB: RandomEventOption(
      label: 'Sessiz Kal',
      description: 'İtibar -8, taraftar -10 · Moral çöküşü (−5)',
      reputationDelta: -8,
      fanInterestDelta: -10,
      moraleFormDelta: -5,
    ),
  ),
  RandomEvent(
    id: 'akademi_prog',
    kind: RandomEventKind.youngTalent,
    title: 'Genç Akademi Yatırımı',
    narrative:
        'Akademiye özel vites programı için bütçe isteniyor; futbol cephesi daha çok hisseder.',
    optionA: RandomEventOption(
      label: 'Programı Başlat',
      description:
          '-25.000 €, futbolda taraftar +10 · Moral +5 (Futbol)',
      treasuryDelta: -25000,
      fanInterestDelta: 10,
      moraleFormDelta: 5,
      targetBranch: 'Futbol',
      moraleTargetBranch: 'Futbol',
    ),
    optionB: RandomEventOption(
      label: 'Şimdilik Ertele',
      description: 'Kasa korunur · Moral değişmez',
    ),
  ),
  RandomEvent(
    id: 'tesisat_acil',
    kind: RandomEventKind.infrastructureIssue,
    title: 'Tesisat Aciliyeti',
    narrative:
        'Kompleks tesisinde arıza. Erken müdahale nakit çıkar.'
        ' Ertelemek tepki yaratır.',
    optionA: RandomEventOption(
      label: 'Hemen Onar',
      description: '-40.000 € · Moral rahat (+2)'
          '',
      treasuryDelta: -40000,
      moraleFormDelta: 2,
    ),
    optionB: RandomEventOption(
      label: 'Ertele',
      description:
          '-10.000 € şimdi, taraftar -8 · Moral −3',
      treasuryDelta: -10000,
      fanInterestDelta: -8,
      moraleFormDelta: -3,
    ),
  ),
];
