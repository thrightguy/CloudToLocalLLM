class LlmModel {
  final String id;
  final String name;
  final String provider; // 'ollama', 'lmstudio', 'openai', 'anthropic', etc.
  final int? size; // Size in MB
  final String? description;
  final bool isInstalled;
  final bool isDownloading;
  final double? downloadProgress;
  final DateTime? lastUsed;
  final bool
      isPremium; // Indicates if this is a premium model requiring subscription

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
    this.isPremium = false,
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
    bool? isPremium,
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
      isPremium: isPremium ?? this.isPremium,
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
      'isPremium': isPremium,
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
      lastUsed:
          json['lastUsed'] != null ? DateTime.parse(json['lastUsed']) : null,
      isPremium: json['isPremium'] ?? false,
    );
  }
}
