import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/model_data.dart';

class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  final List<ModelData> _favorites = [];

  List<ModelData> get favorites => List.unmodifiable(_favorites);
  int get count => _favorites.length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('favorites') ?? [];
    _favorites.clear();
    for (final item in data) {
      try {
        final json = jsonDecode(item) as Map<String, dynamic>;
        _favorites.add(ModelData.fromJson(json));
      } catch (_) {}
    }
    notifyListeners();
  }

  bool isFavorite(int modelId) {
    return _favorites.any((m) => m.id == modelId);
  }

  Future<void> addFavorite(ModelData model) async {
    if (!isFavorite(model.id)) {
      _favorites.add(model);
      await _save();
      notifyListeners();
    }
  }

  Future<void> removeFavorite(int modelId) async {
    _favorites.removeWhere((m) => m.id == modelId);
    await _save();
    notifyListeners();
  }

  Future<void> toggleFavorite(ModelData model) async {
    if (isFavorite(model.id)) {
      await removeFavorite(model.id);
    } else {
      await addFavorite(model);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _favorites.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList('favorites', data);
  }
}
