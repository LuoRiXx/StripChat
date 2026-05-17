class ModelData {
  final int id;
  final String username;
  final String previewUrl;
  final String previewUrlThumbBig;
  final String previewUrlThumbSmall;
  final bool isLive;
  final bool isHd;
  final String status;
  final String broadcastGender;
  final int age;
  final String country;
  final List<String> languages;
  final String ethnicity;
  final String bodyType;
  final int stripScore;
  final String snapshotUrl;
  final int viewerCount;
  final String hlsUrl;

  ModelData({
    required this.id,
    required this.username,
    this.previewUrl = '',
    this.previewUrlThumbBig = '',
    this.previewUrlThumbSmall = '',
    this.isLive = false,
    this.isHd = false,
    this.status = 'off',
    this.broadcastGender = '',
    this.age = 0,
    this.country = '',
    this.languages = const [],
    this.ethnicity = '',
    this.bodyType = '',
    this.stripScore = 0,
    this.snapshotUrl = '',
    this.viewerCount = 0,
    this.hlsUrl = '',
  });

  factory ModelData.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? 0;
    String snapshot = json['snapshotUrl'] ?? json['previewUrl'] ?? '';
    if (snapshot.isEmpty) {
      snapshot =
          'https://img.strpst.com/thumbs/$id/${id}_webp';
    }

    return ModelData(
      id: id,
      username: json['username'] ?? json['name'] ?? '',
      previewUrl: json['previewUrl'] ?? '',
      previewUrlThumbBig: json['previewUrlThumbBig'] ?? '',
      previewUrlThumbSmall: json['previewUrlThumbSmall'] ?? '',
      isLive: json['isLive'] ?? json['status'] == 'public',
      isHd: json['isHd'] ?? false,
      status: json['status'] ?? 'off',
      broadcastGender: json['broadcastGender'] ?? '',
      age: json['age'] ?? 0,
      country: json['country'] ?? '',
      languages: json['languages'] != null
          ? List<String>.from(json['languages'])
          : [],
      ethnicity: json['ethnicity'] ?? '',
      bodyType: json['bodyType'] ?? '',
      stripScore: json['stripScore'] ?? 0,
      snapshotUrl: snapshot,
      viewerCount: json['viewersCount'] ?? json['viewerCount'] ?? 0,
      hlsUrl: json['hlsUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'previewUrl': previewUrl,
      'previewUrlThumbBig': previewUrlThumbBig,
      'previewUrlThumbSmall': previewUrlThumbSmall,
      'isLive': isLive,
      'isHd': isHd,
      'status': status,
      'broadcastGender': broadcastGender,
      'age': age,
      'country': country,
      'languages': languages,
      'ethnicity': ethnicity,
      'bodyType': bodyType,
      'stripScore': stripScore,
      'snapshotUrl': snapshotUrl,
      'viewerCount': viewerCount,
      'hlsUrl': hlsUrl,
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
