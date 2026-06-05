class Repository {
  final int id;
  final String name;
  final String fullName;
  final String? description;
  final bool isPrivate;
  final String defaultBranch;
  final String ownerLogin;

  Repository({
    required this.id,
    required this.name,
    required this.fullName,
    this.description,
    required this.isPrivate,
    required this.defaultBranch,
    required this.ownerLogin,
  });

  factory Repository.fromJson(Map<String, dynamic> json) {
    return Repository(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      fullName: json['full_name'] ?? '',
      description: json['description'],
      isPrivate: json['private'] ?? false,
      defaultBranch: json['default_branch'] ?? 'main',
      ownerLogin: json['owner'] != null ? json['owner']['login'] : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'full_name': fullName,
      'description': description,
      'private': isPrivate,
      'default_branch': defaultBranch,
      'owner': {'login': ownerLogin},
    };
  }
}
