class Branch {
  final String name;
  final String commitSha;

  Branch({
    required this.name,
    required this.commitSha,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      name: json['name'] ?? '',
      commitSha: json['commit'] != null ? (json['commit']['sha'] ?? '') : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'commit': {'sha': commitSha},
    };
  }
}
