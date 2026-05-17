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
