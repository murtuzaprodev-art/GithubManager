import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../theme/app_theme.dart';

class CreateBranchDialog extends StatefulWidget {
  const CreateBranchDialog({super.key});

  @override
  State<CreateBranchDialog> createState() => _CreateBranchDialogState();
}

class _CreateBranchDialogState extends State<CreateBranchDialog> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<AppStateProvider>(context, listen: false);
    try {
      await provider.createBranch(_nameController.text.trim());
      if (mounted) {
        Navigator.of(context).pop(true); // Success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create branch: ${e.toString().replaceAll('Exception:', '')}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreating = context.watch<AppStateProvider>().isCreatingBranch;
    final sourceBranch = context.watch<AppStateProvider>().selectedBranch?.name ?? 'selected branch';

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.call_split_rounded, color: AppTheme.primaryCyan),
          SizedBox(width: 10),
          Text('Create Branch'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Source branch: $sourceBranch',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Branch Name',
                  hintText: 'feature/new-login-flow',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Branch name is required';
                  }
                  if (RegExp(r'\s').hasMatch(value)) {
                    return 'Branch name cannot contain spaces';
                  }
                  return null;
                },
              ),
            ],
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
