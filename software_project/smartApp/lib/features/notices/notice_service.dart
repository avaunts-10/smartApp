import '../../core/network/api_client.dart';

class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.message,
    this.attachmentUrl,
    this.attachmentName,
    required this.createdBy,
    this.createdByEmail,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String message;
  final String? attachmentUrl;
  final String? attachmentName;
  final int? createdBy;
  final String? createdByEmail;
  final DateTime? createdAt;

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String,
        message: j['message'] as String,
        attachmentUrl: j['attachmentUrl'] as String?,
        attachmentName: j['attachmentName'] as String?,
        createdBy: (j['createdBy'] as num?)?.toInt(),
        createdByEmail: j['createdByEmail'] as String?,
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.tryParse(j['createdAt'] as String),
      );
}

class NoticeService {
  NoticeService(this.api);
  final ApiClient api;

  Future<List<Notice>> list() async {
    final res = await api.getAuthed('/api/notices');
    return ((res['notices'] as List?) ?? const [])
        .map((e) => Notice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Notice> create({
    required String title,
    required String message,
    List<int>? attachmentBytes,
    String? attachmentName,
  }) async {
    final res = await api.postMultipartAuthed(
      '/api/notices',
      {'title': title, 'message': message},
      fileFieldName: attachmentBytes != null ? 'attachment' : null,
      fileBytes: attachmentBytes,
      fileName: attachmentName,
    );
    return Notice.fromJson(res['notice'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) => api.deleteAuthed('/api/notices/$id');
}
