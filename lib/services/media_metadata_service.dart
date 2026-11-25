import '../core/network/http_client.dart';

/// 媒体元数据，对齐后端扁平结构；图片 EXIF / 音频标签 / 视频 ffprobe 共用。
class MediaMetadata {
  const MediaMetadata({
    required this.kind,
    this.width,
    this.height,
    this.durationMs,
    this.title = '',
    this.artist = '',
    this.album = '',
    this.genre = '',
    this.capturedAt = '',
    this.camera = '',
    this.location = '',
    this.extra = const {},
  });

  final String kind;
  final int? width;
  final int? height;
  final int? durationMs;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final String capturedAt;
  final String camera;
  final String location;
  final Map<String, String> extra;

  factory MediaMetadata.fromJson(Map<String, dynamic> json) {
    return MediaMetadata(
      kind: json['kind'] as String? ?? '',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      genre: json['genre'] as String? ?? '',
      capturedAt: json['capturedAt'] as String? ?? '',
      camera: json['camera'] as String? ?? '',
      location: json['location'] as String? ?? '',
      extra: (json['extra'] as Map?)?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ?? const {},
    );
  }
}

/// 媒体元数据查询；不支持的文件由后端返回业务错误，调用方静默忽略即可。
class MediaMetadataService {
  MediaMetadataService._();

  static final MediaMetadataService instance = MediaMetadataService._();

  final _http = HttpClient.instance;

  Future<MediaMetadata> get(String fileId) {
    return _http.request<MediaMetadata>(
      '/file/media-metadata',
      query: {'fileId': fileId},
      dataDecoder: (json) => MediaMetadata.fromJson(json as Map<String, dynamic>),
    );
  }
}
