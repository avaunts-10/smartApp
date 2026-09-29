import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/app_di.dart';
import '../../features/learning/learning_service.dart';
import 'app_shell.dart';

/// Subject-scoped learning materials. Teachers (and admins) upload and
/// delete; everyone else gets a view/download-only list.
class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  bool _loadingSubjects = true;
  bool _loadingMaterials = false;
  String? _error;
  List<Subject> _subjects = const [];
  Subject? _selected;
  List<LearningMaterial> _materials = const [];

  bool get _canManage {
    final role = authService.user.value?.role;
    return role == 'teacher' || role == 'admin';
  }

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _loadingSubjects = true;
      _error = null;
    });
    try {
      final overview = await learningService.overview();
      if (!mounted) return;
      setState(() {
        _subjects = overview.subjects;
        _selected = _subjects.isNotEmpty ? _subjects.first : null;
        _loadingSubjects = false;
      });
      if (_selected != null) _loadMaterials();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingSubjects = false;
      });
    }
  }

  Future<void> _loadMaterials() async {
    final subject = _selected;
    if (subject == null) return;
    setState(() => _loadingMaterials = true);
    try {
      final list = await learningService.materials(subjectId: subject.id);
      if (!mounted) return;
      setState(() {
        _materials = list;
        _loadingMaterials = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingMaterials = false;
      });
    }
  }

  void _selectSubject(Subject s) {
    if (s.id == _selected?.id) return;
    setState(() => _selected = s);
    _loadMaterials();
  }

  Future<void> _addMaterial() async {
    final subject = _selected;
    if (subject == null) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _AddMaterialDialog(subject: subject),
    );
    if (created == true) _loadMaterials();
  }

  Future<void> _delete(LearningMaterial m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${m.title}"?'),
        content:
            const Text('Students will no longer be able to see this material.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await learningService.deleteMaterial(m.id);
      _loadMaterials();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Learning Materials',
      subtitle: _canManage
          ? 'Upload materials for each subject'
          : 'Browse and download materials by subject',
      selectedRoute: '/materials',
      actions: _canManage && _selected != null
          ? [
              FilledButton.icon(
                onPressed: _addMaterial,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Upload Material'),
              ),
            ]
          : null,
      body: _loadingSubjects
          ? const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator()))
          : _subjects.isEmpty
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            _error != null
                                ? 'Could not load subjects\n$_error'
                                : 'No subjects yet.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        ElevatedButton(
                            onPressed: _loadSubjects,
                            child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _subjects.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final s = _subjects[i];
                          final selected = s.id == _selected?.id;
                          return ChoiceChip(
                            label: Text(s.name),
                            selected: selected,
                            onSelected: (_) => _selectSubject(s),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loadingMaterials)
                      const SizedBox(
                          height: 160,
                          child: Center(child: CircularProgressIndicator()))
                    else if (_materials.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text('No materials for this subject yet.',
                              style: TextStyle(
                                  color: Colors.black.withOpacity(0.5))),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (final m in _materials) ...[
                            _MaterialTile(
                              material: m,
                              canDelete: _canManage,
                              onDelete: () => _delete(m),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                  ],
                ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({
    required this.material,
    required this.canDelete,
    required this.onDelete,
  });

  final LearningMaterial material;
  final bool canDelete;
  final VoidCallback onDelete;

  IconData get _icon {
    final type = material.fileType ?? '';
    if (type.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (type.startsWith('image/')) return Icons.image_outlined;
    return Icons.description_outlined;
  }

  Future<void> _open() async {
    await launchUrl(Uri.parse('$apiBaseUrl${material.fileUrl}'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
              blurRadius: 22,
              offset: const Offset(0, 12),
              color: Colors.black.withOpacity(0.06)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: const Color(0xFF2D66F6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(material.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                if (material.description != null &&
                    material.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(material.description!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.black.withOpacity(0.6))),
                ],
                const SizedBox(height: 2),
                Text(material.fileName ?? '',
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.black.withOpacity(0.5))),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _open,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download'),
          ),
          if (canDelete)
            IconButton(
              tooltip: 'Delete material',
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.withOpacity(0.75)),
            ),
        ],
      ),
    );
  }
}

class _AddMaterialDialog extends StatefulWidget {
  const _AddMaterialDialog({required this.subject});
  final Subject subject;

  @override
  State<_AddMaterialDialog> createState() => _AddMaterialDialogState();
}

class _AddMaterialDialogState extends State<_AddMaterialDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  PlatformFile? _file;
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _file = result.files.single);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _err = 'Title is required');
      return;
    }
    final file = _file;
    if (file == null) {
      setState(() => _err = 'Choose a file to upload');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      // file_picker doesn't always populate `bytes` on desktop platforms
      // even with withData: true — fall back to reading the path ourselves.
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) {
        setState(() {
          _err = 'Could not read the selected file';
          _saving = false;
        });
        return;
      }
      await learningService.uploadMaterial(
        subjectId: widget.subject.id,
        title: _title.text.trim(),
        description: _description.text.trim(),
        fileBytes: bytes,
        fileName: file.name,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _err = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Upload Material · ${widget.subject.name}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: Text(_file == null ? 'Choose file' : 'Change file'),
                ),
                if (_file != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_file!.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
            if (_err != null) ...[
              const SizedBox(height: 10),
              Text(_err!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Uploading…' : 'Upload'),
        ),
      ],
    );
  }
}
