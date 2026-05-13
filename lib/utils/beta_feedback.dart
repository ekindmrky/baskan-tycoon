import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Beta geri bildirim adresi. Yayın öncesi kendi [Google Forms] veya
/// [GitHub Issues] bağlantınızla değiştirin.
///
/// Flutter derlemesinde özelleştirmek için:
/// `--dart-define=FEEDBACK_URL=https://example.com/form`
final Uri betaFeedbackLaunchUri =
    Uri.parse(const String.fromEnvironment(
  'FEEDBACK_URL',
  defaultValue: 'https://www.google.com/forms/about/',
));

Future<void> openBetaFeedbackInBrowser(BuildContext? context) async {
  try {
    final uri = betaFeedbackLaunchUri;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok || context == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Bağlantı açılamadı. Varsayılan tarayıcıyı kontrol edin.',
        ),
      ),
    );
  } catch (_) {
    if (context?.mounted ?? false) {
      ScaffoldMessenger.of(context!).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Geri bildirim bağlantısı açılırken hata oluştu.'),
        ),
      );
    }
  }
}
