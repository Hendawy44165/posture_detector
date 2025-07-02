import 'package:shared_preferences/shared_preferences.dart';

class SoundPrefService {
  static const String _soundEnabledKey = 'sound_enabled';
  static SoundPrefService? _instance;
  static SharedPreferences? _prefs;

  SoundPrefService._internal();

  static Future<SoundPrefService> getInstance() async {
    if (_instance == null) {
      _instance = SoundPrefService._internal();
      _prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  bool get soundEnabled => _prefs?.getBool(_soundEnabledKey) ?? true;

  Future<void> setSoundEnabled(bool value) async {
    await _prefs?.setBool(_soundEnabledKey, value);
  }
}
