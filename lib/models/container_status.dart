/// Model representing the status of a user's container
class ContainerStatus {
  final String id;
  final String userId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContainerStatus({
    required this.id,
    required this.userId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContainerStatus.fromJson(Map<String, dynamic> json) {
    return ContainerStatus(
      id: json['id'] as String,
      userId: json['userId'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'ContainerStatus(id: $id, userId: $userId, status: $status)';
  }
}
