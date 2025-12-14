class Comment {
  final int id;
  final String artistName;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.artistName,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      artistName: json['artistName'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
