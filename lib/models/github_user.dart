class GitHubUser {
  final String login;
  final String? name;
  final String avatarUrl;
  final String htmlUrl;

  GitHubUser({
    required this.login,
    this.name,
    required this.avatarUrl,
    required this.htmlUrl,
  });

  factory GitHubUser.fromJson(Map<String, dynamic> json) {
    return GitHubUser(
      login: json['login'] ?? '',
      name: json['name'],
      avatarUrl: json['avatar_url'] ?? '',
      htmlUrl: json['html_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'login': login,
      'name': name,
      'avatar_url': avatarUrl,
      'html_url': htmlUrl,
    };
  }
}
