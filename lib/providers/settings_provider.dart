import 'package:flutter/foundation.dart';

import '../models/settings.dart';
import '../services/storage.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage) {
    _settings = _storage.getSettings();
  }

  /// Re-reads settings from storage.
  void reload() {
    _settings = _storage.getSettings();
    notifyListeners();
  }

  final StorageService _storage;
  late Settings _settings;

  Settings get settings => _settings;

  Future<void> updateSettings(Settings settings) async {
    _settings = settings;
    notifyListeners();
    await _storage.saveSettings(settings);
  }
}
