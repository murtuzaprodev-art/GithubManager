import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/github_user.dart';
import '../models/repository.dart';
import '../models/branch.dart';
import '../services/github_service.dart';
import '../services/storage_service.dart';

class AppStateProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  GitHubService? _githubService;

  GitHubUser? _currentUser;
  List<Repository> _repositories = [];
  Repository? _selectedRepository;
  List<Branch> _branches = [];
  Branch? _selectedBranch;

  String? _selectedFolderPath;
  List<File> _filesToUpload = [];

  // Loading States
  bool _isLoadingUser = false;
  bool _isLoadingRepos = false;
  bool _isLoadingBranches = false;
  bool _isCreatingRepo = false;
  bool _isCreatingBranch = false;
  bool _isUploading = false;

  // Upload Progress States
  int _uploadCurrentFileIndex = 0;
  String _uploadCurrentFileName = '';
  double _uploadProgress = 0.0;

  // Getters
  GitHubUser? get currentUser => _currentUser;
  List<Repository> get repositories => _repositories;
  Repository? get selectedRepository => _selectedRepository;
  List<Branch> get branches => _branches;
  Branch? get selectedBranch => _selectedBranch;
  String? get selectedFolderPath => _selectedFolderPath;
  List<File> get filesToUpload => _filesToUpload;

  bool get isLoadingUser => _isLoadingUser;
  bool get isLoadingRepos => _isLoadingRepos;
  bool get isLoadingBranches => _isLoadingBranches;
  bool get isCreatingRepo => _isCreatingRepo;
  bool get isCreatingBranch => _isCreatingBranch;
  bool get isUploading => _isUploading;

  int get uploadCurrentFileIndex => _uploadCurrentFileIndex;
  String get uploadCurrentFileName => _uploadCurrentFileName;
  double get uploadProgress => _uploadProgress;

  bool get isAuthenticated => _githubService != null;

  // Try to load token on app start
  Future<bool> checkAuth() async {
    _isLoadingUser = true;
    notifyListeners();
    try {
      final token = await _storageService.getToken();
      if (token != null && token.isNotEmpty) {
        _githubService = GitHubService(token);
        _currentUser = await _githubService!.getAuthenticatedUser();
        await fetchRepositories();
        _isLoadingUser = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      // If token is invalid or network error, disconnect
      _githubService = null;
      _currentUser = null;
    }
    _isLoadingUser = false;
    notifyListeners();
    return false;
  }

  // Authenticate with a PAT
  Future<void> login(String token) async {
    _isLoadingUser = true;
    notifyListeners();
    try {
      final service = GitHubService(token);
      final user = await service.getAuthenticatedUser();
      
      // Save token if validation succeeds
      await _storageService.saveToken(token);
      _githubService = service;
      _currentUser = user;
      
      await fetchRepositories();
    } finally {
      _isLoadingUser = false;
      notifyListeners();
    }
  }

  // Clear credentials and state
  Future<void> logout() async {
    await _storageService.deleteToken();
    _githubService = null;
    _currentUser = null;
    _repositories = [];
    _selectedRepository = null;
    _branches = [];
    _selectedBranch = null;
    _selectedFolderPath = null;
    _filesToUpload = [];
    notifyListeners();
  }

  // Fetch Repositories
  Future<void> fetchRepositories() async {
    if (_githubService == null) return;
    _isLoadingRepos = true;
    notifyListeners();
    try {
      _repositories = await _githubService!.fetchRepositories();
      if (_repositories.isNotEmpty) {
        // Automatically select first or default repo
        _selectedRepository = _repositories.first;
        await fetchBranches();
      } else {
        _selectedRepository = null;
        _branches = [];
        _selectedBranch = null;
      }
    } finally {
      _isLoadingRepos = false;
      notifyListeners();
    }
  }

  // Select a repository and automatically load its branches
  Future<void> selectRepository(Repository? repository) async {
    _selectedRepository = repository;
    _branches = [];
    _selectedBranch = null;
    notifyListeners();
    if (repository != null) {
      await fetchBranches();
    }
  }

  // Fetch branches for selected repo
  Future<void> fetchBranches() async {
    if (_githubService == null || _selectedRepository == null) return;
    _isLoadingBranches = true;
    notifyListeners();
    try {
      _branches = await _githubService!.fetchBranches(
        _selectedRepository!.ownerLogin,
        _selectedRepository!.name,
      );
      if (_branches.isNotEmpty) {
        // Try selecting default branch first
        final defaultBranchMatch = _branches.firstWhere(
          (b) => b.name == _selectedRepository!.defaultBranch,
          orElse: () => _branches.first,
        );
        _selectedBranch = defaultBranchMatch;
      } else {
        _selectedBranch = null;
      }
    } catch (e) {
      debugPrint('Gracefully handled error in fetchBranches: $e');
      _branches = [];
      _selectedBranch = null;
    } finally {
      _isLoadingBranches = false;
      notifyListeners();
    }
  }

  // Select branch
  void selectBranch(Branch? branch) {
    _selectedBranch = branch;
    notifyListeners();
  }

  // Create repository
  Future<void> createRepository({
    required String name,
    required String description,
    required bool isPrivate,
  }) async {
    if (_githubService == null) return;
    _isCreatingRepo = true;
    notifyListeners();
    try {
      // Set autoInit to true so the main branch is initialized, allowing branch creations
      final newRepo = await _githubService!.createRepository(
        name: name,
        description: description,
        isPrivate: isPrivate,
        autoInit: true,
      );
      
      try {
        // Refresh repo list
        _repositories = await _githubService!.fetchRepositories();
      } catch (e) {
        debugPrint('Gracefully handled list refresh error in createRepository: $e');
      }

      // Check if the list contains the new repository, if not insert it
      final exists = _repositories.any((r) => r.id == newRepo.id);
      if (!exists) {
        _repositories.insert(0, newRepo);
      }
      
      // Select the new repo
      _selectedRepository = _repositories.firstWhere(
        (r) => r.id == newRepo.id,
        orElse: () => _repositories.isNotEmpty ? _repositories.first : newRepo,
      );
      
      try {
        await fetchBranches();
      } catch (e) {
        debugPrint('Gracefully handled branch fetch error in createRepository: $e');
      }
    } catch (e) {
      debugPrint('Error creating repository: $e');
      rethrow;
    } finally {
      _isCreatingRepo = false;
      notifyListeners();
    }
  }

  // Create branch
  Future<void> createBranch(String newBranchName) async {
    if (_githubService == null || _selectedRepository == null || _selectedBranch == null) {
      throw Exception('Repository or source branch not selected');
    }
    _isCreatingBranch = true;
    notifyListeners();
    try {
      // Get the latest SHA from the source branch
      final sourceSha = await _githubService!.getBranchLatestSha(
        _selectedRepository!.ownerLogin,
        _selectedRepository!.name,
        _selectedBranch!.name,
      );

      // Create new branch using this SHA
      await _githubService!.createBranch(
        owner: _selectedRepository!.ownerLogin,
        repoName: _selectedRepository!.name,
        newBranchName: newBranchName,
        sourceBranchSha: sourceSha,
      );

      // Refresh branches and select the new branch
      await fetchBranches();
      final newBranchIndex = _branches.indexWhere((b) => b.name == newBranchName);
      if (newBranchIndex != -1) {
        _selectedBranch = _branches[newBranchIndex];
      }
    } finally {
      _isCreatingBranch = false;
      notifyListeners();
    }
  }

  // Pick folder from computer
  Future<void> pickFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        _selectedFolderPath = result;
        _filesToUpload = [];

        // Scan files recursively
        final dir = Directory(result);
        if (await dir.exists()) {
          final List<FileSystemEntity> entities = dir.listSync(recursive: true);
          for (final entity in entities) {
            if (entity is File) {
              if (!_shouldIgnore(entity.path, result)) {
                _filesToUpload.add(entity);
              }
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to pick folder: $e');
    }
  }

  // Check if file path should be ignored (VCS, build artifacts)
  bool _shouldIgnore(String filePath, String rootPath) {
    final relativePath = p.relative(filePath, from: rootPath);
    final pathSegments = p.split(relativePath);
    
    for (final segment in pathSegments) {
      final lower = segment.toLowerCase();
      // Ignore hidden files/folders (starting with .)
      if (segment.startsWith('.')) {
        return true;
      }
      // Common dependencies and build folders
      if (lower == 'node_modules' ||
          lower == 'build' ||
          lower == 'dist' ||
          lower == 'bin' ||
          lower == 'obj' ||
          lower == 'dart_tool' ||
          lower == 'packages' ||
          lower == 'ios' ||
          lower == 'android' ||
          lower == 'windows' ||
          lower == 'linux' ||
          lower == 'macos') {
        return true;
      }
    }
    return false;
  }

  // Push all files to GitHub
  Future<void> pushCode(String commitMessage) async {
    if (_githubService == null ||
        _selectedRepository == null ||
        _selectedBranch == null ||
        _selectedFolderPath == null ||
        _filesToUpload.isEmpty) {
      throw Exception('Configuration incomplete. Please select repo, branch, folder and ensure files are present.');
    }

    _isUploading = true;
    _uploadCurrentFileIndex = 0;
    _uploadCurrentFileName = '';
    _uploadProgress = 0.0;
    notifyListeners();

    try {
      final owner = _selectedRepository!.ownerLogin;
      final repo = _selectedRepository!.name;
      final branch = _selectedBranch!.name;

      for (int i = 0; i < _filesToUpload.length; i++) {
        final file = _filesToUpload[i];
        final relativePath = p.relative(file.path, from: _selectedFolderPath!).replaceAll('\\', '/');
        
        _uploadCurrentFileIndex = i + 1;
        _uploadCurrentFileName = p.basename(file.path);
        _uploadProgress = i / _filesToUpload.length;
        notifyListeners();

        // Read file bytes
        final bytes = await file.readAsBytes();
        final base64Content = base64.encode(bytes);

        // Check if file already exists to retrieve SHA
        final existingSha = await _githubService!.getFileSha(
          owner: owner,
          repoName: repo,
          branch: branch,
          path: relativePath,
        );

        // Upload/Update file
        await _githubService!.uploadFile(
          owner: owner,
          repoName: repo,
          branch: branch,
          path: relativePath,
          base64Content: base64Content,
          commitMessage: commitMessage,
          existingSha: existingSha,
        );
      }
      
      _uploadProgress = 1.0;
      notifyListeners();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }
}
