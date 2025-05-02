class LlmModel {
  final String id;
  final String name;
  final String provider; // 'ollama' or 'lmstudio'
  final int? size; // Size in MB
  final String? description;
  final bool isInstalled;
  final bool isDownloading;
  final double? downloadProgress;
  final DateTime? lastUsed;

  LlmModel({
    required this.id,
    required this.name,
    required this.provider,
    this.size,
    this.description,
    this.isInstalled = false,
    this.isDownloading = false,
    this.downloadProgress,
    this.lastUsed,
  });

  // Create a copy of this model with updated fields
  LlmModel copyWith({
    String? id,
    String? name,
    String? provider,
    int? size,
    String? description,
    bool? isInstalled,
    bool? isDownloading,
    double? downloadProgress,
    DateTime? lastUsed,
  }) {
    return LlmModel(
      id: id ?? this.id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      size: size ?? this.size,
      description: description ?? this.description,
      isInstalled: isInstalled ?? this.isInstalled,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  // Convert model to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'provider': provider,
      'size': size,
      'description': description,
      'isInstalled': isInstalled,
      'lastUsed': lastUsed?.toIso8601String(),
    };
  }

  // Create model from JSON
  factory LlmModel.fromJson(Map<String, dynamic> json) {
    return LlmModel(
      id: json['id'],
      name: json['name'],
      provider: json['provider'],
      size: json['size'],
      description: json['description'],
      isInstalled: json['isInstalled'] ?? false,
      lastUsed: json['lastUsed'] != null ? DateTime.parse(json['lastUsed']) : null,
    );
  }
}