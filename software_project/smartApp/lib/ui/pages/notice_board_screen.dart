import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/app_di.dart';
import '../../features/notices/notice_service.dart';
import 'app_shell.dart';

/// Teacher-created announcements, visible to every role. Teachers (and
/// admins) can post and delete; everyone else gets a read-only board.
class NoticeBoardScreen extends StatefulWidget {
  const NoticeBoardScreen({super.key});

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  bool _loading = true;
  String? _error;
  List<Notice> _notices = const [];

  bool get _canManage {
    final role = authService.user.value?.role;
    return role == 'teacher' || role == 'admin';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final n = await noticeService.list();
      if (!mounted) return;
      setState(() {
        _notices = n;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _addNotice() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddNoticeDialog(),
    );
    if (created == true) _load();
  }

  Future<void> _delete(Notice n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${n.title}"?'),
        content: const Text('This notice will be removed for everyone.'),
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
      await noticeService.delete(n.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Notice Board',
      subtitle: _canManage
          ? 'Post announcements for all students'
          : 'Announcements from your teachers',
      selectedRoute: '/notices',
      actions: _canManage
          ? [
              FilledButton.icon(
                onPressed: _addNotice,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Notice'),
              ),
            ]
          : null,
      body: _loading
          ? const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Could not load notices\n$_error',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _notices.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text('No notices yet.',
                            style: TextStyle(
                                color: Colors.black.withOpacity(0.5))),
                      ),
                    )
                  : Column(
                      children: [
                        for (final n in _notices) ...[
                          _NoticeCard(
                            notice: n,
                            canDelete: _canManage,
                            onDelete: () => _delete(n),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.canDelete,
    required this.onDelete,
  });

  final Notice notice;
  final bool canDelete;
  final VoidCallback onDelete;

  Future<void> _openAttachment() async {
    final url = notice.attachmentUrl;
    if (url == null) return;
    await launchUrl(Uri.parse('$apiBaseUrl$url'),
        mode: LaunchMode.externalApplication);
  }

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_outlined,
                    color: Color(0xFF2D66F6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notice.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (notice.createdByEmail != null)
                          notice.createdByEmail!.split('@').first,
                        if (notice.createdAt != null)
                          _formatDate(notice.createdAt!),
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              if (canDelete)
                IconButton(
                  tooltip: 'Delete notice',
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline,
                      color: Colors.red.withOpacity(0.75)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(notice.message,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.black.withOpacity(0.75))),
          if (notice.hasAttachment) ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _openAttachment,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_file, size: 16),
                    const SizedBox(width: 6),
                    Text(notice.attachmentName ?? 'Attachment',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddNoticeDialog extends StatefulWidget {
  const _AddNoticeDialog();

  @override
  State<_AddNoticeDialog> createState() => _AddNoticeDialogState();
}

class _AddNoticeDialogState extends State<_AddNoticeDialog> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  PlatformFile? _file;
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _file = result.files.single);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      setState(() => _err = 'Title and message are required');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      final file = _file;
      List<int>? attachmentBytes;
      if (file != null) {
        // file_picker doesn't always populate `bytes` on desktop platforms
        // even with withData: true — fall back to reading the path ourselves.
        attachmentBytes = file.bytes ??
            (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (attachmentBytes == null) {
          setState(() {
            _err = 'Could not read the selected file';
            _saving = false;
          });
          return;
        }
      }
      await noticeService.create(
        title: _title.text.trim(),
        message: _message.text.trim(),
        attachmentBytes: attachmentBytes,
        attachmentName: file?.name,
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
      title: const Text('New Notice'),
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
              controller: _message,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Message', alignLabelWithHint: true),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: Text(
                      _file == null ? 'Attach file (optional)' : 'Change file'),
                ),
                if (_file != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_file!.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _file = null),
                    icon: const Icon(Icons.close, size: 16),
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
          child: Text(_saving ? 'Posting…' : 'Post'),
        ),
      ],
    );
  }
}
