import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../theme/app_theme.dart';

class CreateRepoDialog extends StatefulWidget {
  const CreateRepoDialog({super.key});

  @override
  State<CreateRepoDialog> createState() => _CreateRepoDialogState();
}

class _CreateRepoDialogState extends State<CreateRepoDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPrivate = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<AppStateProvider>(context, listen: false);
    try {
      await provider.createRepository(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        isPrivate: _isPrivate,
      );
      if (mounted) {
        Navigator.of(context).pop(true); // Success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create repository: ${e.toString().replaceAll('Exception:', '')}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreating = context.watch<AppStateProvider>().isCreatingRepo;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.create_new_folder_rounded, color: AppTheme.primaryCyan),
          SizedBox(width: 10),
          Text('Create Repository'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Repository Name',
                    hintText: 'my-awesome-project',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Repository name is required';
                    }
                    if (RegExp(r'[^a-zA-Z0-9._-]').hasMatch(value)) {
                      return 'Only letters, numbers, -, _, and . are allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Describe your repository...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Private Repository'),
                  subtitle: const Text('Only authorized users can see this repository.'),
                  value: _isPrivate,
                  activeThumbColor: AppTheme.primaryCyan,
                  onChanged: (val) {
                    setState(() {
                      _isPrivate = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isCreating ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        isCreating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Create'),
              ),
      ],
    );
  }
}
