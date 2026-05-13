import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:presidento/logic/game_provider.dart';
import 'dashboard_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // -------------------------------------------------------------------------
  // Sabitler
  // -------------------------------------------------------------------------
  /// Branşa dağıtılabilir toplam: `GameProvider.initialTreasuryEuros` ile aynı kapak.
  static double get _treasuryEuros =>
      GameProvider.initialTreasuryEuros;

  /// Slider ve kurulum sırasında 0’a inebilir; göndermede gösterge alt sınırı.
  static const double _sliderMinEuros = 0.0;

  /// Kulüpleri kurmak için gönder tuşlarında gereken gerçek branş başına taban €.
  static const double _minBranchAllocateSubmit = 50000;

  // -------------------------------------------------------------------------
  // Controllers & state
  // -------------------------------------------------------------------------
  final _formKey = GlobalKey<FormState>();
  final _presidentNameCtrl = TextEditingController();
  final _presidentAgeCtrl = TextEditingController();
  final _clubNameCtrl = TextEditingController();

  String? _selectedCity;
  Color _primaryColor = const Color(0xFF1565C0);
  Color _secondaryColor = const Color(0xFFFFBF00);

  double _footballBudget = 0;
  double _basketballBudget = 0;
  double _volleyballBudget = 0;

  bool _isSubmitting = false;

  // -------------------------------------------------------------------------
  // Hesaplanan değerler
  // -------------------------------------------------------------------------
  double get _allocatedBudget =>
      _footballBudget + _basketballBudget + _volleyballBudget;

  double get _remainingBudget => _treasuryEuros - _allocatedBudget;

  /// Diğer iki branşın toplam dağıtımı (bu branş hariç) — preset vb.
  double _othersSumExcluding(String branch) {
    if (branch == CountryData.football) {
      return _basketballBudget + _volleyballBudget;
    }
    if (branch == CountryData.basketball) {
      return _footballBudget + _volleyballBudget;
    }
    return _footballBudget + _basketballBudget;
  }

  bool get _meetsMinimumPerBranchAllocations =>
      _footballBudget >= _minBranchAllocateSubmit &&
      _basketballBudget >= _minBranchAllocateSubmit &&
      _volleyballBudget >= _minBranchAllocateSubmit;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------
  @override
  void dispose() {
    _presidentNameCtrl.dispose();
    _presidentAgeCtrl.dispose();
    _clubNameCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------
  void _openColorPicker({
    required Color initial,
    required String title,
    required ValueChanged<Color> onPicked,
  }) {
    Color temp = initial;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: temp,
            onColorChanged: (c) => temp = c,
            pickerAreaHeightPercent: 0.7,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              onPicked(temp);
              Navigator.pop(context);
            },
            child: const Text('Seç'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCityPicker() async {
    final cities = CountryData.turkishCities;
    List<String> filtered = List.from(cities);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2744),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (_, scrollCtrl) => Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF8A9BB8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextField(
                  autofocus: true,
                  style: GoogleFonts.rajdhani(
                      color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Şehir ara...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF8A9BB8)),
                    filled: true,
                    fillColor: const Color(0xFF2C3546),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setModal(() {
                    filtered = cities
                        .where((c) =>
                            c.toLowerCase().contains(v.toLowerCase()))
                        .toList();
                  }),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final city = filtered[i];
                    final selected = city == _selectedCity;
                    return ListTile(
                      title: Text(
                        city,
                        style: GoogleFonts.rajdhani(
                          fontSize: 17,
                          color: selected
                              ? const Color(0xFFFFBF00)
                              : Colors.white,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded,
                              color: Color(0xFFFFBF00))
                          : null,
                      onTap: () {
                        setState(() => _selectedCity = city);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCity == null) {
      _showError('Lütfen bir şehir seçin.');
      return;
    }
    if (_remainingBudget < 0) {
      _showError(
        'Yetersiz Bütçe: üç branşın toplamı kasayı '
        '(${GameProvider.initialTreasuryEuros ~/ 1000} K €) geçemez.',
      );
      return;
    }
    if (!_meetsMinimumPerBranchAllocations) {
      _showError(
        'Her branş için en az ${(_minBranchAllocateSubmit ~/ 1000)} K € ayırın.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    context.read<GameProvider>().createClub(
          clubName: _clubNameCtrl.text.trim(),
          city: _selectedCity!,
          primaryColor:
              '#${(_primaryColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
          secondaryColor:
              '#${(_secondaryColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
          presidentName: _presidentNameCtrl.text.trim(),
          presidentAge: int.parse(_presidentAgeCtrl.text.trim()),
          branchBudgets: {
            CountryData.football: _footballBudget,
            CountryData.basketball: _basketballBudget,
            CountryData.volleyball: _volleyballBudget,
          },
        );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1628), Color(0xFF1A2744), Color(0xFF0D1F3C)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _sectionCard(
                        icon: Icons.person_rounded,
                        title: 'Başkan Bilgileri',
                        children: [
                          _buildTextField(
                            controller: _presidentNameCtrl,
                            label: 'Başkan Adı',
                            hint: 'Adınızı girin',
                            icon: Icons.badge_outlined,
                            validator: _notEmpty,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _presidentAgeCtrl,
                            label: 'Yaş',
                            hint: '30',
                            icon: Icons.cake_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              _MaxValueFormatter(99),
                            ],
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Boş bırakılamaz';
                              final age = int.tryParse(v);
                              if (age == null || age < 18 || age > 99) {
                                return '18–99 arası bir yaş girin';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _sectionCard(
                        icon: Icons.sports_soccer_rounded,
                        title: 'Kulüp Bilgileri',
                        children: [
                          _buildTextField(
                            controller: _clubNameCtrl,
                            label: 'Kulüp Adı',
                            hint: 'Örn: Anadolu Spor',
                            icon: Icons.shield_outlined,
                            validator: _notEmpty,
                          ),
                          const SizedBox(height: 14),
                          _buildCitySelector(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _sectionCard(
                        icon: Icons.palette_rounded,
                        title: 'Kulüp Renkleri',
                        children: [
                          _buildColorRow(
                            label: 'Ana Renk',
                            color: _primaryColor,
                            onTap: () => _openColorPicker(
                              initial: _primaryColor,
                              title: 'Ana Renk Seç',
                              onPicked: (c) =>
                                  setState(() => _primaryColor = c),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildColorRow(
                            label: 'İkincil Renk',
                            color: _secondaryColor,
                            onTap: () => _openColorPicker(
                              initial: _secondaryColor,
                              title: 'İkincil Renk Seç',
                              onPicked: (c) =>
                                  setState(() => _secondaryColor = c),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBudgetCard(),
                      const SizedBox(height: 28),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Küçük widget'lar
  // -------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          const Icon(Icons.sports_soccer_rounded,
              color: Color(0xFFFFBF00), size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kulüp Başkanı Tycoon',
                style: GoogleFonts.rajdhani(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Kulübünü Kur',
                style: GoogleFonts.rajdhani(
                  fontSize: 13,
                  color: const Color(0xFFFFBF00),
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2530),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2C3546),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFBF00), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFBF00),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF8A9BB8), size: 20),
      ),
    );
  }

  Widget _buildCitySelector() {
    return GestureDetector(
      onTap: _openCityPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3546),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_city_rounded,
                color: Color(0xFF8A9BB8), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedCity ?? 'Şehir seçin (81 il)',
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  color: _selectedCity != null
                      ? Colors.white
                      : const Color(0xFF8A9BB8),
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded,
                color: Color(0xFF8A9BB8)),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRow({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.rajdhani(
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              color: const Color(0xFF8A9BB8),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.edit_rounded,
              color: Color(0xFFFFBF00), size: 18),
        ],
      ),
    );
  }

  // Şampiyonluk (Aggressive) bütçesi — kurulum sırasında hep L1 (index 0).
  static double _aggressiveFor(String branch) =>
      BranchLeagueData.aggressiveBudget(branch, 0);

  // Slider üst sınırı: 2 × şampiyonluk (L1 aggressive) önerisi — ör. Futbol 150k × 2 = 300k.
  double _sliderMax(String branch) =>
      math.max(1.0, _aggressiveFor(branch) * 2);

  /// Hazır seçenekleri uygula; kasa veya kulübe sığmayınca Yetersiz Bütçe uyarır.
  void _applyPreset(String branch, double targetValue) {
    final slotMax = _sliderMax(branch);
    // Preset tuşları oynanabilir alt sınıra çıksın (göndermede doğrulanır).
    var wish =
        math.max(targetValue, _minBranchAllocateSubmit.toDouble());
    wish = wish.clamp(_sliderMinEuros, slotMax);
    final others = _othersSumExcluding(branch);
    final treasuryHeadroom =
        (GameProvider.initialTreasuryEuros - others).clamp(0.0, _treasuryEuros);
    final hi = math.min(slotMax, treasuryHeadroom);
    final assigned = wish.clamp(_sliderMinEuros, hi);

    setState(() {
      if (branch == CountryData.football) _footballBudget = assigned;
      if (branch == CountryData.basketball) _basketballBudget = assigned;
      if (branch == CountryData.volleyball) _volleyballBudget = assigned;
    });

    const eps = 0.5;
    if (wish - assigned > eps) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Yetersiz Bütçe: ${_branchDisplayName(branch)} için hedef '
          '${_formatAmount(wish)}, kasada sığabilecek ${_formatAmount(assigned)}.',
          style: GoogleFonts.rajdhani(fontSize: 14),
        ),
        backgroundColor: const Color(0xFFE53935),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  String _branchDisplayName(String branch) {
    if (branch == CountryData.football)   return 'Futbol';
    if (branch == CountryData.basketball) return 'Basketbol';
    return 'Voleybol';
  }

  Widget _buildBudgetCard() {
    final remaining    = _remainingBudget;
    final isOverBudget = remaining < 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2530),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverBudget
              ? const Color(0xFFFF5252)
              : const Color(0xFF2C3546),
          width: isOverBudget ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Color(0xFFFFBF00), size: 20),
              const SizedBox(width: 8),
              Text(
                'Bütçe Dağılımı',
                style: GoogleFonts.rajdhani(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFBF00), letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _budgetChip(
                  label: 'Kasa', amount: _treasuryEuros, color: const Color(0xFF8A9BB8)),
              _budgetChip(label: 'Dağıtılan',amount: _allocatedBudget,color: const Color(0xFF4FC3F7)),
              _budgetChip(
                label: 'Kalan Kasa',
                amount: remaining,
                color: isOverBudget ? const Color(0xFFFF5252) : const Color(0xFF69F0AE),
              ),
            ],
          ),
          if (isOverBudget) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 16),
                const SizedBox(width: 6),
                Text('Yetersiz Bütçe: dağıtım kasayı aştı.',
                    style: GoogleFonts.rajdhani(fontSize: 13, color: const Color(0xFFFF5252))),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _buildBranchSection(
            branch:    CountryData.football,
            label:     'Futbol',
            icon:      Icons.sports_soccer_rounded,
            color:     const Color(0xFF69F0AE),
            value:     _footballBudget,
            onChanged: (value) {
              final otherBudgets =
                  _basketballBudget + _volleyballBudget;
              if (value + otherBudgets <= GameProvider.initialTreasuryEuros) {
                setState(() => _footballBudget = value);
              } else {
                setState(() => _footballBudget =
                    GameProvider.initialTreasuryEuros - otherBudgets);
              }
              // ignore: avoid_print
              print(
                  'Futbol: $_footballBudget, Toplam: ${_footballBudget + otherBudgets}');
            },
          ),
          const SizedBox(height: 20),
          _buildBranchSection(
            branch:    CountryData.basketball,
            label:     'Basketbol',
            icon:      Icons.sports_basketball_rounded,
            color:     const Color(0xFF4FC3F7),
            value:     _basketballBudget,
            onChanged: (value) {
              final otherBudgets =
                  _footballBudget + _volleyballBudget;
              if (value + otherBudgets <= GameProvider.initialTreasuryEuros) {
                setState(() => _basketballBudget = value);
              } else {
                setState(() => _basketballBudget =
                    GameProvider.initialTreasuryEuros - otherBudgets);
              }
              // ignore: avoid_print
              print(
                  'Basketbol: $_basketballBudget, Toplam: ${_basketballBudget + otherBudgets}');
            },
          ),
          const SizedBox(height: 20),
          _buildBranchSection(
            branch:    CountryData.volleyball,
            label:     'Voleybol',
            icon:      Icons.sports_volleyball_rounded,
            color:     const Color(0xFFFFBF00),
            value:     _volleyballBudget,
            onChanged: (value) {
              final otherBudgets =
                  _footballBudget + _basketballBudget;
              if (value + otherBudgets <= GameProvider.initialTreasuryEuros) {
                setState(() => _volleyballBudget = value);
              } else {
                setState(() => _volleyballBudget =
                    GameProvider.initialTreasuryEuros - otherBudgets);
              }
              // ignore: avoid_print
              print(
                  'Voleybol: $_volleyballBudget, Toplam: ${_volleyballBudget + otherBudgets}');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBranchSection({
    required String branch,
    required String label,
    required IconData icon,
    required Color color,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final aggressive = _aggressiveFor(branch);
    const maxTreasury = GameProvider.initialTreasuryEuros;
    final sliderValue =
        value.clamp(_sliderMinEuros, maxTreasury);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık + mevcut bütçe
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.rajdhani(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            const Spacer(),
            Text(_formatAmount(value),
                style: GoogleFonts.rajdhani(
                    fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        // Preset butonları
        Row(
          children: [
            _presetButton(
              label: 'Şampiyonluk',
              color: color,
              onTap: () => _applyPreset(branch, aggressive),
            ),
            const SizedBox(width: 6),
            _presetButton(
              label: 'Gençlere Yatırım',
              color: color.withValues(alpha: 0.7),
              onTap: () => _applyPreset(branch, aggressive * 0.6),
            ),
            const SizedBox(width: 6),
            _presetButton(
              label: 'Kümede Kalma',
              color: const Color(0xFF8A9BB8),
              onTap: () => _applyPreset(branch, aggressive * 0.3),
            ),
          ],
        ),
        // Slider: max sabit kasa; sınır sadece onChanged içinde.
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: const Color(0xFF2C3546),
            overlayColor: color.withValues(alpha: 0.15),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: sliderValue,
            min: _sliderMinEuros,
            max: maxTreasury,
            divisions: ((maxTreasury - _sliderMinEuros) / 10000)
                .round()
                .clamp(1, 200),
            onChanged: onChanged,
          ),
        ),
        // Referans çizgisi: Aggressive hedefi
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.5), shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              'Şampiyonluk hedefi: ${_formatAmount(aggressive)}',
              style: GoogleFonts.rajdhani(
                  fontSize: 10, color: const Color(0xFF8A9BB8)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _presetButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
      );

  Widget _budgetChip({
    required String label,
    required double amount,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            color: const Color(0xFF8A9BB8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatAmount(amount),
          style: GoogleFonts.rajdhani(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }


  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: (_isSubmitting ||
                _remainingBudget < 0 ||
                !_meetsMinimumPerBranchAllocations)
            ? null
            : _submit,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF0A1628),
                ),
              )
            : const Icon(Icons.rocket_launch_rounded),
        label: Text(
          _isSubmitting ? 'Kuruluyor...' : 'Kulübü Kur',
          style: GoogleFonts.rajdhani(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFBF00),
          foregroundColor: const Color(0xFF0A1628),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor:
              const Color(0xFFFFBF00).withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Yardımcılar
  // -------------------------------------------------------------------------
  String? _notEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Bu alan boş bırakılamaz' : null;

  /// Bütçe için okunaklı gösterim (öneriler milyon € ölçeğinde vurgulanır).
  String _formatAmount(double amount) {
    if (amount.abs() >= 1000000) {
      final m = amount / 1000000;
      final s = m >= 10 ? m.toStringAsFixed(1) : m.toStringAsFixed(2);
      return '$s M€';
    }
    if (amount.abs() >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)} K€';
    }
    return '${amount.toStringAsFixed(0)} €';
  }
}

// ---------------------------------------------------------------------------
// Yardımcı formatter — yaş alanı için max değer sınırı
// ---------------------------------------------------------------------------
class _MaxValueFormatter extends TextInputFormatter {
  final int max;
  _MaxValueFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final val = int.tryParse(newValue.text);
    if (val != null && val > max) return oldValue;
    return newValue;
  }
}
