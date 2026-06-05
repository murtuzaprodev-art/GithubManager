import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../../models/repository.dart';
import '../../models/branch.dart';
import '../theme/app_theme.dart';
import '../widgets/create_repo_dialog.dart';
import '../widgets/create_branch_dialog.dart';
import '../widgets/upload_progress_dialog.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _commitMessageController =
      TextEditingController(text: 'Initial commit via GitHub Manager Pro');
  final ScrollController _fileListScrollController = ScrollController();

  @override
  void dispose() {
    _commitMessageController.dispose();
    _fileListScrollController.dispose();
    super.dispose();
  }

  void _showCreateRepo() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateRepoDialog(),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Repository created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showCreateBranch() async {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    if (provider.selectedRepository == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a repository first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (provider.selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source branch not found. Repository might be empty. Try creating a repository with auto-init enabled.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateBranchDialog(),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Branch created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handlePush() async {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    if (provider.selectedRepository == null ||
        provider.selectedBranch == null ||
        provider.selectedFolderPath == null ||
        provider.filesToUpload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify repo, branch, folder, and files are selected.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UploadProgressDialog(),
    );

    try {
      await provider.pushCode(_commitMessageController.text.trim());
      // The progress dialog stays up showing 100% or closes when they click "Close" in the dialog.
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString().replaceAll('Exception:', '')}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    await provider.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final user = provider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.terminal_rounded, color: AppTheme.primaryCyan),
            SizedBox(width: 8),
            Text('GitHub Manager Pro'),
          ],
        ),
        actions: [
          if (user != null) ...[
            CircleAvatar(
              backgroundImage: NetworkImage(user.avatarUrl),
              radius: 16,
            ),
            const SizedBox(width: 8),
            Text(
              user.name ?? user.login,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Sidebar - Configuration & Control Panel
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section: Repo Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Repository Settings',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Icon(Icons.inventory_2_outlined, color: AppTheme.primaryCyan, size: 20),
                            ],
                          ),
                          const SizedBox(height: 16),
                          provider.isLoadingRepos
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : DropdownButtonFormField<Repository>(
                                  initialValue: provider.selectedRepository,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Repository',
                                  ),
                                  items: provider.repositories.map((repo) {
                                    return DropdownMenuItem<Repository>(
                                      value: repo,
                                      child: Text(
                                        repo.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (repo) => provider.selectRepository(repo),
                                ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _showCreateRepo,
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Create New Repository'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section: Branch Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Branch Settings',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Icon(Icons.call_split_rounded, color: AppTheme.accentPurple, size: 20),
                            ],
                          ),
                          const SizedBox(height: 16),
                          provider.isLoadingBranches
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : DropdownButtonFormField<Branch>(
                                  initialValue: provider.selectedBranch,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Branch',
                                  ),
                                  items: provider.branches.map((branch) {
                                    return DropdownMenuItem<Branch>(
                                      value: branch,
                                      child: Text(
                                        branch.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (branch) => provider.selectBranch(branch),
                                ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: provider.selectedRepository == null ? null : _showCreateBranch,
                            icon: const Icon(Icons.fork_right_rounded, size: 20),
                            label: const Text('Create New Branch'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section: Commit & Push Settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Commit Configuration',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _commitMessageController,
                            decoration: const InputDecoration(
                              labelText: 'Commit Message',
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (provider.selectedRepository == null ||
                                      provider.selectedBranch == null ||
                                      provider.selectedFolderPath == null ||
                                      provider.filesToUpload.isEmpty)
                                  ? null
                                  : _handlePush,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryCyan,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload_rounded),
                                  SizedBox(width: 8),
                                  Text('Push Folder to GitHub'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right Sidebar - Folder Scan & File Sync
          VerticalDivider(width: 1, color: AppTheme.borderGrey),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Local Directory Sync',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a folder on your computer to push to the selected GitHub repository and branch.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  
                  // Folder picker card
                  Card(
                    color: Colors.black26,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sync Folder Path',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.selectedFolderPath ?? 'No folder selected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: provider.selectedFolderPath == null
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    color: provider.selectedFolderPath == null
                                        ? AppTheme.textSecondary
                                        : Colors.white,
                                    fontFamily: 'monospace',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: provider.pickFolder,
                            icon: const Icon(Icons.folder_open_rounded),
                            label: const Text('Choose Folder'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // List of Files to Upload header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Files to Upload (${provider.filesToUpload.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (provider.filesToUpload.isNotEmpty)
                        const Text(
                          'Excluding build & VCS files',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // File List preview
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderGrey),
                      ),
                      child: provider.filesToUpload.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder_off_rounded, size: 48, color: AppTheme.borderGrey),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No files found to sync.\nChoose a folder containing files.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : Scrollbar(
                              controller: _fileListScrollController,
                              child: ListView.separated(
                                controller: _fileListScrollController,
                                padding: const EdgeInsets.all(8),
                                itemCount: provider.filesToUpload.length,
                                separatorBuilder: (context, index) => Divider(color: AppTheme.borderGrey.withValues(alpha: 0.5), height: 1),
                                itemBuilder: (context, index) {
                                  final file = provider.filesToUpload[index];
                                  final name = provider.selectedFolderPath != null
                                      ? file.path.replaceFirst(provider.selectedFolderPath!, '')
                                      : file.path;

                                  return ListTile(
                                    leading: const Icon(Icons.insert_drive_file_outlined, color: AppTheme.primaryCyan, size: 20),
                                    title: Text(
                                      name,
                                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                                    ),
                                    trailing: Text(
                                      '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                    ),
                                    dense: true,
                                  );
                                },
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
