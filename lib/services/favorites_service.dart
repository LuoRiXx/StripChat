import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/model_data.dart';
import 'web_data_fetcher.dart';

class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  final List<ModelData> _favorites = [];
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;

  List<ModelData> get favorites => List.unmodifiable(_favorites);
  List<ModelData> get liveFavorites =>
      _favorites.where((m) => m.isCurrentlyLive).toList();
  List<ModelData> get offlineFavorites =>
      _favorites.where((m) => !m.isCurrentlyLive).toList();
  int get count => _favorites.length;
  int get liveCount => liveFavorites.length;
  bool get isRefreshing => _isRefreshing;

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

  /// 刷新所有收藏的在播状态、观看人数、封面
  Future<void> refreshLiveStatus({bool force = false}) async {
    if (_isRefreshing) return;
    if (!force &&
        _lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!).inSeconds < 30) {
      return;
    }
    if (_favorites.isEmpty) return;

    _isRefreshing = true;
    notifyListeners();

    try {
      final fetcher = WebDataFetcher();
      // 并发拉取每个主播的最新状态（限制并发数 5）
      const concurrency = 5;
      for (int i = 0; i < _favorites.length; i += concurrency) {
        final batch = _favorites.skip(i).take(concurrency);
        await Future.wait(batch.map((m) async {
          try {
            final raw = await fetcher.fetchJson(
              'https://zh.stripchat.com/api/front/v1/broadcasts/${m.username}?uniq=${DateTime.now().millisecondsSinceEpoch}',
            );
            if (raw == null || raw.isEmpty) return;
            if (raw.trimLeft().startsWith('<')) return;
            final data = jsonDecode(raw);
            final item = data['item'];
            if (item is! Map<String, dynamic>) return;
            final idx = _favorites.indexWhere((x) => x.id == m.id);
            if (idx < 0) return;
            final isLive = item['isLive'] == true ||
                item['status'] == 'public' ||
                item['status'] == 'private' ||
                item['status'] == 'p2p' ||
                item['status'] == 'groupShow' ||
                item['status'] == 'virtualPrivate';
            final viewerCount =
                item['viewersCount'] ?? item['viewerCount'] ?? 0;
            final snapshot = (item['snapshotUrl'] ?? '').toString();
            _favorites[idx] = _favorites[idx].copyWith(
              isLive: isLive,
              status: (item['status'] ?? _favorites[idx].status).toString(),
              viewerCount: viewerCount is int
                  ? viewerCount
                  : int.tryParse('$viewerCount') ?? 0,
              snapshotUrlRaw: snapshot.isNotEmpty ? snapshot : null,
            );
          } catch (_) {}
        }));
      }
      await _save();
      _lastRefreshTime = DateTime.now();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _favorites.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList('favorites', data);
  }
}
