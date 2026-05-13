import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:presidento/logic/game_provider.dart';
import 'package:presidento/utils/beta_feedback.dart';
import 'dashboard_screen.dart';
import 'setup_screen.dart';

/// Uygulama giriş akışı — sade, profesyonel dark arayüz.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  static const _prefsSfx = 'presidento_menu_sfx_enabled';

  bool _canLoadSave = false;
  bool _checkingSave = true;
  bool _sfxOn = true;

  @override
  void initState() {
    super.initState();
    _refreshSaveState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sfxOn = prefs.getBool(_prefsSfx) ?? true;
    });
  }

  Future<void> _refreshSaveState() async {
    final ok = await GameProvider.hasSavedGame();
    if (!mounted) return;
    setState(() {
      _canLoadSave = ok;
      _checkingSave = false;
    });
  }

  Future<void> _setSfx(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsSfx, v);
    if (mounted) setState(() => _sfxOn = v);
  }

  Future<void> _onNewGame() async {
    if (_canLoadSave && mounted) {
      final go = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              backgroundColor: const Color(0xFF161E2E),
              title: Text(
                'Yeni oyun',
                style: GoogleFonts.rajdhani(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              content: Text(
                'Mevcut kayıt silinecek ve kulüp kurulumuna gideceksin. Devam?',
                style:
                    GoogleFonts.rajdhani(color: const Color(0xFF94A3B8), height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: Text(
                    'İptal',
                    style:
                        GoogleFonts.rajdhani(color: const Color(0xFF94A3B8)),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8)),
                  child: Text('Devam et',
                      style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ) ??
          false;
      if (!go || !mounted) return;
      await context.read<GameProvider>().clearSaveAndReset();
      if (!mounted) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SetupScreen()),
    );
    if (!mounted) return;
    await _refreshSaveState();
  }

  Future<void> _onLoadGame() async {
    if (!_canLoadSave || _checkingSave) return;
    final gp = context.read<GameProvider>();
    if (!mounted) return;
    setState(() => _checkingSave = true);
    final ok = await gp.loadGame();
    if (!mounted) return;
    setState(() => _checkingSave = false);
    if (ok) {
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (_) => false,
      );
      await _refreshSaveState();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kayıt bulunamadı veya bozuk.',
            style: GoogleFonts.rajdhani(),
          ),
        ),
      );
      await _refreshSaveState();
    }
  }

  Future<void> _promptWipeAllData(BuildContext navigatorContext) async {
    final go = await showDialog<bool>(
      context: navigatorContext,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF161E2E),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFF5252), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tam veri sıfırlama',
                style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'SharedPreferences dahil yerel ayarların hepsi silinir; oyuncu seçimleri de '
          '(ör. ses) sıfırlanır. Devam etmek istiyor musun?',
          style: GoogleFonts.rajdhani(
            color: const Color(0xFF94A3B8),
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text('İptal',
                style: GoogleFonts.rajdhani(color: const Color(0xFF94A3B8))),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text('Temizle',
                style:
                    GoogleFonts.rajdhani(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await context.read<GameProvider>().wipeAllSharedPreferencesAndReset();
    await _refreshSaveState();
    await _loadPrefs();
    if (mounted) setState(() {});
  }

  void _showSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ayarlar',
                    style: GoogleFonts.rajdhani(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gelecek güncellemede dil, bildirimler ve ses motoru bağlanır.',
                    style: GoogleFonts.rajdhani(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SwitchListTile.adaptive(
                    value: _sfxOn,
                    onChanged: (v) async {
                      await _setSfx(v);
                      setModal(() {});
                    },
                    activeTrackColor:
                        const Color(0xFF38BDF8).withValues(alpha: 0.35),
                    activeThumbColor: const Color(0xFF38BDF8),
                    title: Text(
                      'Ses efektleri (önizlik)',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Oyunda henüz ses çıktısı yok; seçim kaydedilir.',
                      style:
                          GoogleFonts.rajdhani(color: const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        openBetaFeedbackInBrowser(context);
                      });
                    },
                    icon: Icon(
                      Icons.feedback_outlined,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                    label: Text(
                      'Hata Bildir / Öneri Ver',
                      style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF5252),
                      side: const BorderSide(color: Color(0xFFB71C1C)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        if (!mounted) return;
                        await _promptWipeAllData(context);
                      });
                    },
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: Text(
                      'Verileri sıfırla (tam temizlik)',
                      style:
                          GoogleFonts.rajdhani(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Geliştirme: SharedPreferences tamamen sıfırlanır.',
                    style: GoogleFonts.rajdhani(
                        fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child:
                        Text('Kapat', style: GoogleFonts.rajdhani()),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).disabledColor;

    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1222), Color(0xFF080F1E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(
                  Icons.sports_soccer_rounded,
                  size: 48,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.9),
                ),
                const SizedBox(height: 20),
                Text(
                  'Kulüp Başkanı Tycoon',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Profesyonel kulüp yönetimi simülasyonu',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                    fontSize: 14,
                    color: const Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _checkingSave ? null : _onNewGame,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0A1628),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Yeni Oyun',
                    style: GoogleFonts.rajdhani(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: (_canLoadSave && !_checkingSave)
                      ? _onLoadGame
                      : null,
                  icon: Icon(
                    Icons.folder_open_rounded,
                    color: _canLoadSave && !_checkingSave
                        ? const Color(0xFF0A1628)
                        : muted,
                  ),
                  label: Text(
                    _checkingSave
                        ? 'Kontrol ediliyor…'
                        : 'Oyunu Yükle'
                            '${_canLoadSave ? '' : ' (Kayıt yok)'}',
                    style: GoogleFonts.rajdhani(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _canLoadSave && !_checkingSave
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF1E293B),
                    foregroundColor: _canLoadSave && !_checkingSave
                        ? const Color(0xFF0A1628)
                        : muted,
                    disabledBackgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showSettingsSheet,
                  icon: const Icon(Icons.settings_outlined),
                  label:
                      Text('Ayarlar', style: GoogleFonts.rajdhani()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE2E8F0),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => openBetaFeedbackInBrowser(context),
                  icon: Icon(
                    Icons.feedback_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(
                    'Hata Bildir / Öneri Ver',
                    style: GoogleFonts.rajdhani(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFB8C9DF),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
