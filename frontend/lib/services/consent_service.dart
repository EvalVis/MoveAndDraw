import 'package:shared_preferences/shared_preferences.dart';

class ConsentService {
  static const String _googleDataConsentKey = 'google_data_consent';
  static const String _locationDataConsentKey = 'location_data_consent';

  Future<bool> hasGoogleDataConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_googleDataConsentKey) ?? false;
  }

  Future<bool> hasLocationDataConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_locationDataConsentKey) ?? false;
  }

  Future<bool> hasAllConsents() async {
    final googleConsent = await hasGoogleDataConsent();
    final locationConsent = await hasLocationDataConsent();
    return googleConsent && locationConsent;
  }

  Future<void> setGoogleDataConsent(bool consented) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_googleDataConsentKey, consented);
  }

  Future<void> setLocationDataConsent(bool consented) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationDataConsentKey, consented);
  }

  Future<void> clearAllConsents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_googleDataConsentKey);
    await prefs.remove(_locationDataConsentKey);
  }
}

