class ModelData {
  final int id;
  final String username;
  final String previewUrlThumbSmall;
  final String previewUrlThumbBig;
  final String snapshotUrlRaw;
  final String avatarUrl;
  final String hlsPlaylist;
  final bool isLive;
  final bool isHd;
  final String status;
  final String broadcastGender;
  final int age;
  final String country;
  final int viewerCount;
  final bool isNew;
  final bool isMobile;
  final bool isLovense;
  final String streamName;
  final List<String> presets;
  final int broadcastWidth;
  final int broadcastHeight;

  static const String _imageBase = 'https://img.doppiocdn.com';

  ModelData({
    required this.id,
    required this.username,
    this.previewUrlThumbSmall = '',
    this.previewUrlThumbBig = '',
    this.snapshotUrlRaw = '',
    this.avatarUrl = '',
    this.hlsPlaylist = '',
    this.isLive = false,
    this.isHd = false,
    this.status = 'off',
    this.broadcastGender = '',
    this.age = 0,
    this.country = '',
    this.viewerCount = 0,
    this.isNew = false,
    this.isMobile = false,
    this.isLovense = false,
    this.streamName = '',
    this.presets = const [],
    this.broadcastWidth = 0,
    this.broadcastHeight = 0,
  });

  String _resolveUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('//')) return 'https:$raw';
    if (raw.startsWith('/')) return '$_imageBase$raw';
    return '$_imageBase/$raw';
  }

  /// 优先大图、次之 raw、再之小图
  String get snapshotUrl {
    if (snapshotUrlRaw.isNotEmpty) return _resolveUrl(snapshotUrlRaw);
    if (previewUrlThumbBig.isNotEmpty) return _resolveUrl(previewUrlThumbBig);
    if (previewUrlThumbSmall.isNotEmpty) {
      return _resolveUrl(previewUrlThumbSmall);
    }
    // 没有有效封面就返回空，让 errorWidget 显示占位图，避免拼接错误的 URL
    return '';
  }

  String get fullAvatarUrl => _resolveUrl(avatarUrl);

  String get hlsUrl {
    if (hlsPlaylist.isNotEmpty) return hlsPlaylist;
    final sn = streamName.isNotEmpty ? streamName : '$id';
    if (sn.isEmpty || sn == '0') return '';
    return 'https://edge-hls.doppiocdn.com/hls/$sn/master/$sn.m3u8';
  }

  String get hlsBestUrl => hlsUrl;

  /// 是否正在直播（用于过滤未开播）
  bool get isCurrentlyLive {
    return isLive ||
        status == 'public' ||
        status == 'private' ||
        status == 'p2p' ||
        status == 'groupShow' ||
        status == 'virtualPrivate';
  }

  ModelData copyWith({
    bool? isLive,
    String? status,
    int? viewerCount,
    String? snapshotUrlRaw,
    String? previewUrlThumbBig,
  }) {
    return ModelData(
      id: id,
      username: username,
      previewUrlThumbSmall: previewUrlThumbSmall,
      previewUrlThumbBig: previewUrlThumbBig ?? this.previewUrlThumbBig,
      snapshotUrlRaw: snapshotUrlRaw ?? this.snapshotUrlRaw,
      avatarUrl: avatarUrl,
      hlsPlaylist: hlsPlaylist,
      isLive: isLive ?? this.isLive,
      isHd: isHd,
      status: status ?? this.status,
      broadcastGender: broadcastGender,
      age: age,
      country: country,
      viewerCount: viewerCount ?? this.viewerCount,
      isNew: isNew,
      isMobile: isMobile,
      isLovense: isLovense,
      streamName: streamName,
      presets: presets,
      broadcastWidth: broadcastWidth,
      broadcastHeight: broadcastHeight,
    );
  }

  factory ModelData.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? 0;
    final broadcastSettings =
        json['broadcastSettings'] as Map<String, dynamic>? ?? {};
    final username = json['username'] ?? json['name'] ?? '';

    return ModelData(
      id: id,
      username: username,
      previewUrlThumbSmall: (json['previewUrlThumbSmall'] ??
              json['previewUrl'] ??
              '')
          .toString(),
      previewUrlThumbBig: (json['previewUrlThumbBig'] ??
              json['snapshotUrl'] ??
              json['previewUrl'] ??
              '')
          .toString(),
      snapshotUrlRaw: (json['snapshotUrl'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
      hlsPlaylist: (json['hlsPlaylist'] ?? '').toString(),
      isLive: json['isLive'] ?? (json['status'] == 'public'),
      isHd: json['isHd'] ?? false,
      status: json['status'] ?? 'off',
      broadcastGender: (json['broadcastGender'] ?? '').toString(),
      age: json['age'] ?? 0,
      country: (json['country'] ?? '').toString(),
      viewerCount: json['viewersCount'] ?? json['viewerCount'] ?? 0,
      isNew: json['isNew'] ?? false,
      isMobile: json['isMobile'] ?? false,
      isLovense: json['isLovense'] ?? false,
      streamName: (json['streamName'] ?? '$id').toString(),
      presets: json['presets'] != null
          ? List<String>.from(
              (json['presets'] as List).where((p) => p != null))
          : [],
      broadcastWidth: broadcastSettings['width'] ?? 0,
      broadcastHeight: broadcastSettings['height'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'previewUrlThumbSmall': previewUrlThumbSmall,
      'previewUrlThumbBig': previewUrlThumbBig,
      'snapshotUrl': snapshotUrlRaw,
      'avatarUrl': avatarUrl,
      'hlsPlaylist': hlsPlaylist,
      'isLive': isLive,
      'isHd': isHd,
      'status': status,
      'broadcastGender': broadcastGender,
      'age': age,
      'country': country,
      'viewersCount': viewerCount,
      'isNew': isNew,
      'isMobile': isMobile,
      'isLovense': isLovense,
      'streamName': streamName,
      'presets': presets,
      'broadcastSettings': {
        'width': broadcastWidth,
        'height': broadcastHeight,
      },
    };
  }
}

class ModelBlock {
  final String id;
  final String title;
  final String type;
  final List<ModelData> models;

  ModelBlock({
    required this.id,
    required this.title,
    this.type = '',
    required this.models,
  });

  factory ModelBlock.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawModels = json['models'] ?? json['items'] ?? [];
    final models = rawModels
        .whereType<Map<String, dynamic>>()
        .map(ModelData.fromJson)
        .toList();

    final rawId = (json['id'] ??
            json['blockId'] ??
            json['type'] ??
            json['name'] ??
            '')
        .toString();

    return ModelBlock(
      id: rawId,
      title: _resolveTitle(json),
      type: (json['type'] ?? '').toString(),
      models: models,
    );
  }

  static String _resolveTitle(Map<String, dynamic> json) {
    final candidates = [
      json['localizedTitle'],
      json['title'],
      json['name'],
      json['displayName'],
      json['blockTitle'],
      json['type'],
      json['id'],
    ];
    for (final c in candidates) {
      if (c != null && c.toString().isNotEmpty) {
        return _localizeBlockTitle(c.toString());
      }
    }
    return '推荐主播';
  }

  static String _localizeBlockTitle(String raw) {
    final key = raw.toLowerCase().replaceAll('_', '').replaceAll('-', '').replaceAll(' ', '');
    const mapping = <String, String>{
      'recommended': '今日为您推荐',
      'recommendedforyou': '今日为您推荐',
      'recommendedmodels': '今日为您推荐',
      'recommendedmodelsblock': '今日为您推荐',
      'topmodels': '热门主播',
      'topmodelsblock': '热门主播',
      'top': '热门推送',
      'matched': '匹配您的最新精选',
      'matchedforyou': '匹配您的最新精选',
      'matchedmodels': '匹配您的最新精选',
      'matchedmodelsblock': '匹配您的最新精选',
      'matchedforyoublock': '匹配您的最新精选',
      'recentlywatched': '最近观看',
      'recentlywatchedmodels': '最近观看',
      'recentlywatchedblock': '最近观看',
      'favorites': '我的最爱',
      'favoritemodels': '我的最爱',
      'favoritesblock': '我的最爱',
      'newmodels': '推荐的新美女主播',
      'newgirls': '推荐的新美女主播',
      'newmodelsblock': '推荐的新美女主播',
      'new': '新主播',
      'newblock': '新主播',
      'chinese': '中文性爱直播',
      'china': '中文性爱直播',
      'chinesemodels': '中文性爱直播',
      'asian': '亚洲主播',
      'free': '超赞免费性爱直播',
      'freemodels': '超赞免费性爱直播',
      'awesomefree': '超赞免费性爱直播',
      'awesomefreesexcams': '超赞免费性爱直播',
      'mobile': '移动端性爱直播',
      'mobilemodels': '移动端性爱直播',
      'mobilesexcams': '移动端性爱直播',
      'lovense': 'Lovense 互动',
      'hd': '高清直播',
      'hdmodels': '高清直播',
      '4k': '4K 高清直播',
      'private': '私人秀',
      'privateshow': '私人秀',
      'privateshows': '私人秀',
      'bestprivate': '最佳私人秀',
      'bestprivateshow': '最佳私人秀',
      'vr': 'VR 摄像头',
      'vrmodels': 'VR 摄像头',
      'bdsm': '虐恋',
      'fetish': '虐恋',
      'ticketshow': '购票表演',
      'ticketshows': '购票表演',
      'couples': '情侣主播',
      'guys': '男主播',
      'trans': '变性主播',
      'girls': '女主播',
      'similar': '相似主播',
      'forfans': '粉丝专属',
      'ukraine': '乌克兰女主播',
      'ukrainian': '乌克兰女主播',
      'asians': '亚洲女主播',
      'latina': '拉丁主播',
      'european': '欧洲主播',
      'russian': '俄罗斯主播',
      'newlyactive': '近期活跃',
      'currentbroadcasts': '当前直播',
      'allmodels': '全部主播',
      'top21mostpopular': '人气榜前 21',
      'topmostviewed': '观看量最高',
      'discover': '发现更多',
      'mostpopularblock': '人气榜',
      'newgirlsblock': '推荐的新美女主播',
    };
    final mapped = mapping[key];
    if (mapped != null) return mapped;
    // 尝试包含匹配（针对带后缀的 key）
    for (final entry in mapping.entries) {
      if (key.contains(entry.key) && entry.key.length >= 5) {
        return entry.value;
      }
    }
    return raw;
  }
}

class ChatMessage {
  final String username;
  final String message;
  final DateTime timestamp;
  final bool isSystem;

  ChatMessage({
    required this.username,
    required this.message,
    required this.timestamp,
    this.isSystem = false,
  });
}
