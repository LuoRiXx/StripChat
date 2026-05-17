class ModelData {
  final int id;
  final String username;
  final String previewUrlThumbSmall;
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

  static const String _imageBase = 'https://static-proxy.strpst.com';

  ModelData({
    required this.id,
    required this.username,
    this.previewUrlThumbSmall = '',
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

  String get snapshotUrl {
    if (previewUrlThumbSmall.isEmpty) return '';
    if (previewUrlThumbSmall.startsWith('http')) return previewUrlThumbSmall;
    return '$_imageBase$previewUrlThumbSmall';
  }

  String get fullAvatarUrl {
    if (avatarUrl.isEmpty) return '';
    if (avatarUrl.startsWith('http')) return avatarUrl;
    return '$_imageBase$avatarUrl';
  }

  String get hlsUrl {
    if (hlsPlaylist.isNotEmpty) return hlsPlaylist;
    final sn = streamName.isNotEmpty ? streamName : '$id';
    if (sn.isEmpty || sn == '0') return '';
    return 'https://edge-hls.doppiocdn.com/hls/$sn/master/$sn.m3u8';
  }

  String get hlsBestUrl => hlsUrl;

  factory ModelData.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? 0;
    final broadcastSettings =
        json['broadcastSettings'] as Map<String, dynamic>? ?? {};

    return ModelData(
      id: id,
      username: json['username'] ?? json['name'] ?? '',
      previewUrlThumbSmall: json['previewUrlThumbSmall'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      hlsPlaylist: json['hlsPlaylist'] ?? '',
      isLive: json['isLive'] ?? (json['status'] == 'public'),
      isHd: json['isHd'] ?? false,
      status: json['status'] ?? 'off',
      broadcastGender: json['broadcastGender'] ?? '',
      age: json['age'] ?? 0,
      country: json['country'] ?? '',
      viewerCount: json['viewersCount'] ?? json['viewerCount'] ?? 0,
      isNew: json['isNew'] ?? false,
      isMobile: json['isMobile'] ?? false,
      isLovense: json['isLovense'] ?? false,
      streamName: json['streamName'] ?? '$id',
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
        .where((m) => m.status == 'public' || m.isLive)
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
    final key = raw.toLowerCase().replaceAll('_', '').replaceAll('-', '');
    const mapping = <String, String>{
      'recommended': '今日为您推荐',
      'recommendedforyou': '今日为您推荐',
      'topmodels': '热门主播',
      'topmodelsblock': '热门主播',
      'top': '热门推送',
      'matched': '匹配您的最新精选',
      'matchedforyou': '匹配您的最新精选',
      'matchedmodels': '匹配您的最新精选',
      'recentlywatched': '最近观看',
      'favorites': '我的最爱',
      'newmodels': '推荐的新美女主播',
      'newgirls': '推荐的新美女主播',
      'new': '新主播',
      'chinese': '中文性爱直播',
      'china': '中文性爱直播',
      'asian': '亚洲主播',
      'free': '超赞免费性爱直播',
      'mobile': '移动端性爱直播',
      'lovense': 'Lovense 互动',
      'hd': '高清直播',
      '4k': '4K 高清直播',
      'private': '私人秀',
      'private show': '私人秀',
      'vr': 'VR 摄像头',
      'bdsm': '虐恋',
      'fetish': '虐恋',
      'ticketshow': '购票表演',
      'ticketshows': '购票表演',
      'couples': '情侣主播',
      'guys': '男主播',
      'trans': '变性主播',
      'girls': '女主播',
      'recommendedmodels': '今日为您推荐',
      'similar': '相似主播',
      'forfans': '粉丝专属',
    };
    return mapping[key] ?? raw;
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
