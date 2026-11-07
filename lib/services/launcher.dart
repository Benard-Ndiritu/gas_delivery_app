import 'package:url_launcher/url_launcher.dart';

/// Opens phone, email, WhatsApp and maps links in the appropriate app.
class Launcher {
  static Future<bool> open(String url) async {
    try {
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> call(String phone) => open('tel:${phone.replaceAll(' ', '')}');

  static Future<bool> email(String address, {String subject = ''}) =>
      open('mailto:$address${subject.isEmpty ? '' : '?subject=${Uri.encodeComponent(subject)}'}');

  static Future<bool> whatsapp(String internationalNumber, {String text = ''}) =>
      open('https://wa.me/$internationalNumber${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}');

  static Future<bool> directions(dynamic latitude, dynamic longitude) =>
      open('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');
}
