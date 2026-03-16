class VideoEdit {
  final String id;
  final String videoUrl;
  final String title;
  final DateTime uploadedAt;

  VideoEdit({
    required this.id,
    required this.videoUrl,
    required this.title,
    required this.uploadedAt,
  });

  factory VideoEdit.fromFirestore(Map<String, dynamic> data, String docId) {
    return VideoEdit(
      id: docId,
      videoUrl: data['videoUrl'] as String,
      title: data['title'] as String? ?? 'Untitled',
      uploadedAt: data['uploadedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['uploadedAt'] as int)
          : DateTime.now(),
    );
  }
}
