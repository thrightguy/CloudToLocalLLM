class User {
  final String id;
  final String username;
  final String? email;
  final String? name; // Display name
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    this.email,
    this.name,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
