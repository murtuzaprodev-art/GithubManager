import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/github_user.dart';
import '../models/repository.dart';
import '../models/branch.dart';

class GitHubService {
  final String token;
  static const String _baseUrl = 'https://api.github.com';

  GitHubService(this.token);

  Map<String, String> get _headers {
    final authPrefix = token.startsWith('github_pat_') ? 'Bearer' : 'token';
    return {
      'Authorization': '$authPrefix $token',
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
    };
  }

  // Get authenticated user info to validate the token
  Future<GitHubUser> getAuthenticatedUser() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/user'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final scopesHeader = response.headers['x-oauth-scopes'];
      if (scopesHeader != null) {
        final scopes = scopesHeader.split(',').map((s) => s.trim().toLowerCase()).toList();
        if (!scopes.contains('repo') && !scopes.contains('public_repo')) {
          debugPrint('WARNING: Token does not contain "repo" or "public_repo" scope.');
        }
      }
      return GitHubUser.fromJson(json.decode(response.body));
    } else {
      throw _parseError(response);
    }
  }

  // Fetch repositories owned by the user
  Future<List<Repository>> fetchRepositories() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/user/repos?per_page=100&type=owner'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Repository.fromJson(json)).toList();
    } else {
      throw _parseError(response);
    }
  }

  // Fetch branches of a repository
  Future<List<Branch>> fetchBranches(String owner, String repoName) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repoName/branches?per_page=100'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Branch.fromJson(json)).toList();
    } else {
      throw _parseError(response);
    }
  }

  // Create repository
  Future<Repository> createRepository({
    required String name,
    required String description,
    required bool isPrivate,
    required bool autoInit,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/user/repos'),
      headers: _headers,
      body: json.encode({
        'name': name,
        'description': description,
        'private': isPrivate,
        'auto_init': autoInit,
      }),
    );

    if (response.statusCode == 201) {
      return Repository.fromJson(json.decode(response.body));
    } else {
      throw _parseError(response);
    }
  }

  // Get latest commit SHA of a branch
  Future<String> getBranchLatestSha(String owner, String repoName, String branchName) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repoName/git/ref/heads/$branchName'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['object']['sha'];
    } else {
      throw _parseError(response);
    }
  }

  // Create new branch from source branch SHA
  Future<void> createBranch({
    required String owner,
    required String repoName,
    required String newBranchName,
    required String sourceBranchSha,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/repos/$owner/$repoName/git/refs'),
      headers: _headers,
      body: json.encode({
        'ref': 'refs/heads/$newBranchName',
        'sha': sourceBranchSha,
      }),
    );

    if (response.statusCode != 201) {
      throw _parseError(response);
    }
  }

  // Check if a file exists on the given branch, returning its SHA if it does
  Future<String?> getFileSha({
    required String owner,
    required String repoName,
    required String branch,
    required String path,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repoName/contents/$path?ref=$branch'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['sha'];
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw _parseError(response);
    }
  }

  // Upload or update a file via the Contents API
  Future<void> uploadFile({
    required String owner,
    required String repoName,
    required String branch,
    required String path,
    required String base64Content,
    required String commitMessage,
    String? existingSha,
  }) async {
    final body = {
      'message': commitMessage,
      'content': base64Content,
      'branch': branch,
    };
    if (existingSha != null) {
      body['sha'] = existingSha;
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/repos/$owner/$repoName/contents/$path'),
      headers: _headers,
      body: json.encode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _parseError(response);
    }
  }

  // General error parser for GitHub API responses
  Exception _parseError(http.Response response) {
    try {
      final body = json.decode(response.body);
      String message = body['message'] ?? 'Unknown API error';
      if (response.statusCode == 404 && message.toLowerCase() == 'not found') {
        message = 'Not Found. Please ensure your Personal Access Token has the "repo" scope enabled.';
      }
      return Exception('GitHub Error (${response.statusCode}): $message');
    } catch (_) {
      return Exception('HTTP Error (${response.statusCode}): ${response.reasonPhrase}');
    }
  }
}
