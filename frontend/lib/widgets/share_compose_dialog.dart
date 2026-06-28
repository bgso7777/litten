import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';

/// 공유 작성 결과 — 대상(개인/그룹) + 메시지.
class ShareComposeResult {
  final String targetType; // 'user' | 'group'
  final String? recipientKey; // user
  final int? groupId; // group
  final String? message;
  const ShareComposeResult({
    required this.targetType,
    this.recipientKey,
    this.groupId,
    this.message,
  });
}

/// 파일을 누구에게(개인/그룹) 공유할지 고르는 다이얼로그.
Future<ShareComposeResult?> showShareComposeDialog(BuildContext context,
    {required String fileLabel}) {
  return showDialog<ShareComposeResult>(
    context: context,
    builder: (ctx) => _ShareComposeDialog(fileLabel: fileLabel),
  );
}

class _ShareComposeDialog extends StatefulWidget {
  final String fileLabel;
  const _ShareComposeDialog({required this.fileLabel});

  @override
  State<_ShareComposeDialog> createState() => _ShareComposeDialogState();
}

class _ShareComposeDialogState extends State<_ShareComposeDialog> {
  bool _toGroup = false; // false=개인, true=그룹
  final _recipientCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  int? _selectedGroupId;
  // 수신자 확인 결과
  bool? _lookupFound;
  String? _lookupName;
  bool _looking = false;

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyRecipient() async {
    final key = _recipientCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() => _looking = true);
    final r = await context.read<AppStateProvider>().lookupShareRecipient(key);
    if (!mounted) return;
    setState(() {
      _looking = false;
      _lookupFound = r == null ? null : (r['found'] == true);
      _lookupName = r?['name']?.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final appState = context.watch<AppStateProvider>();
    final groups = appState.shareGroups;

    return AlertDialog(
      title: const Text('공유', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fileLabel,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            // 대상 토글: 개인 / 그룹
            Row(children: [
              Expanded(child: _segBtn('개인', !_toGroup, () => setState(() => _toGroup = false), color)),
              const SizedBox(width: 8),
              Expanded(child: _segBtn('그룹', _toGroup, () => setState(() => _toGroup = true), color)),
            ]),
            const SizedBox(height: 12),
            if (!_toGroup) ...[
              TextField(
                controller: _recipientCtrl,
                autofocus: true,
                onChanged: (_) {
                  if (_lookupFound != null) {
                    setState(() {
                      _lookupFound = null;
                      _lookupName = null;
                    });
                  }
                },
                onSubmitted: (_) => _verifyRecipient(),
                decoration: InputDecoration(
                  labelText: '받는 사람 (이메일 또는 닉네임)',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: _looking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : TextButton(onPressed: _verifyRecipient, child: const Text('확인')),
                ),
              ),
              if (_lookupFound == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(children: [
                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('${_lookupName ?? ''} 님',
                        style: const TextStyle(fontSize: 12, color: Colors.green)),
                  ]),
                ),
              if (_lookupFound == false)
                const Padding(
                  padding: EdgeInsets.only(top: 4, left: 4),
                  child: Text('해당 사용자를 찾을 수 없습니다.',
                      style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
            ] else ...[
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedGroupId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: '그룹 선택', isDense: true, border: OutlineInputBorder()),
                    items: groups
                        .map((g) => DropdownMenuItem<int>(
                              value: (g['groupId'] as num).toInt(),
                              child: Text('${g['name']} (${g['memberCount']}명)',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedGroupId = v),
                  ),
                ),
                IconButton(
                  tooltip: '그룹 관리',
                  icon: Icon(Icons.settings, color: color),
                  onPressed: () async {
                    await showShareGroupManageDialog(context);
                    if (mounted) setState(() {}); // 그룹 변경 반영
                  },
                ),
              ]),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('그룹이 없습니다. 우측 톱니바퀴로 만들어 주세요.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _messageCtrl,
              decoration: const InputDecoration(
                  labelText: '메시지 (선택)', isDense: true, border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
          onPressed: () {
            final msg = _messageCtrl.text.trim();
            if (_toGroup) {
              if (_selectedGroupId == null) {
                _snack('그룹을 선택하세요.');
                return;
              }
              Navigator.pop(
                  context,
                  ShareComposeResult(
                      targetType: 'group', groupId: _selectedGroupId, message: msg.isEmpty ? null : msg));
            } else {
              final key = _recipientCtrl.text.trim();
              if (key.isEmpty) {
                _snack('받는 사람을 입력하세요.');
                return;
              }
              Navigator.pop(
                  context,
                  ShareComposeResult(
                      targetType: 'user', recipientKey: key, message: msg.isEmpty ? null : msg));
            }
          },
          child: const Text('보내기'),
        ),
      ],
    );
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _segBtn(String label, bool active, VoidCallback onTap, Color color) {
    return Material(
      color: active ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active ? color : Colors.grey.withValues(alpha: 0.3), width: 1),
          ),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: active ? color : Colors.grey.shade600)),
        ),
      ),
    );
  }
}

/// 특정 그룹의 멤버 추가/제거 다이얼로그 (홈 그룹 헤더의 멤버 아이콘에서 호출).
Future<void> showGroupMembersDialog(
    BuildContext context, int groupId, String groupName) {
  return showDialog(
    context: context,
    builder: (ctx) => _GroupMembersDialog(groupId: groupId, groupName: groupName),
  );
}

/// 그룹 관리(생성/삭제 + 멤버 추가/제거) 다이얼로그.
Future<void> showShareGroupManageDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (ctx) => const _ShareGroupManageDialog(),
  );
}

class _ShareGroupManageDialog extends StatefulWidget {
  const _ShareGroupManageDialog();
  @override
  State<_ShareGroupManageDialog> createState() => _ShareGroupManageDialogState();
}

class _ShareGroupManageDialogState extends State<_ShareGroupManageDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateProvider>().reloadShareGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final appState = context.watch<AppStateProvider>();
    final groups = appState.shareGroups;

    return AlertDialog(
      title: const Text('그룹 관리', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 그룹 생성 (이름 + 비밀번호 + 멤버)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await showDialog(
                      context: context, builder: (_) => const _CreateGroupDialog());
                  if (mounted) context.read<AppStateProvider>().reloadShareGroups();
                },
                icon: Icon(Icons.group_add, color: color),
                label: const Text('새 그룹 만들기'),
              ),
            ),
            const Divider(),
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('그룹이 없습니다.'),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: groups.map((g) {
                    final gid = (g['groupId'] as num).toInt();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${g['name']}'),
                      subtitle: Text('${g['memberCount']}명'),
                      onTap: () => _manageMembers(context, gid, '${g['name']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () async {
                          await appState.deleteShareGroup(gid);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      ],
    );
  }

  Future<void> _manageMembers(BuildContext context, int groupId, String name) async {
    await showDialog(
      context: context,
      builder: (ctx) => _GroupMembersDialog(groupId: groupId, groupName: name),
    );
    if (mounted) context.read<AppStateProvider>().reloadShareGroups();
  }
}

/// 새 그룹 만들기 — 이름 + (선택)비밀번호 + 멤버(이메일/닉네임) 다중 추가.
class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();
  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _memberCtrl = TextEditingController();
  final List<String> _members = [];
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pwCtrl.dispose();
    _memberCtrl.dispose();
    super.dispose();
  }

  void _addMember() {
    final k = _memberCtrl.text.trim();
    if (k.isEmpty) return;
    if (!_members.contains(k)) setState(() => _members.add(k));
    _memberCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return AlertDialog(
      title: const Text('새 그룹', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: '그룹 이름', isDense: true, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: '비밀번호 (선택)', isDense: true, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _memberCtrl,
                  decoration: const InputDecoration(
                      labelText: '멤버 추가 (이메일/닉네임)',
                      isDense: true, border: OutlineInputBorder()),
                  onSubmitted: (_) => _addMember(),
                ),
              ),
              IconButton(icon: Icon(Icons.add_circle, color: color), onPressed: _addMember),
            ]),
            if (_members.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _members
                      .map((m) => Chip(
                            label: Text(m, style: const TextStyle(fontSize: 12)),
                            onDeleted: () => setState(() => _members.remove(m)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
          onPressed: _saving
              ? null
              : () async {
                  final name = _nameCtrl.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('그룹 이름을 입력하세요.')));
                    return;
                  }
                  final pending = _memberCtrl.text.trim();
                  final members = [
                    ..._members,
                    if (pending.isNotEmpty && !_members.contains(pending)) pending
                  ];
                  setState(() => _saving = true);
                  final pw = _pwCtrl.text.trim();
                  final g = await context
                      .read<AppStateProvider>()
                      .createShareGroup(name, password: pw.isEmpty ? null : pw, members: members);
                  if (!mounted) return;
                  Navigator.pop(context);
                  final nf = (g?['notFound'] as List?)?.length ?? 0;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(g == null
                        ? '그룹 생성 실패'
                        : (nf > 0 ? '그룹 생성됨 (찾지 못한 사용자 $nf명 제외)' : '그룹을 만들었습니다.')),
                  ));
                },
          child: const Text('만들기'),
        ),
      ],
    );
  }
}

class _GroupMembersDialog extends StatefulWidget {
  final int groupId;
  final String groupName;
  const _GroupMembersDialog({required this.groupId, required this.groupName});
  @override
  State<_GroupMembersDialog> createState() => _GroupMembersDialogState();
}

class _GroupMembersDialogState extends State<_GroupMembersDialog> {
  final _keyCtrl = TextEditingController();
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await context.read<AppStateProvider>().getShareGroupMembers(widget.groupId);
    if (mounted) setState(() { _members = m; _loading = false; });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final appState = context.read<AppStateProvider>();
    return AlertDialog(
      title: Text('${widget.groupName} 멤버', style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _keyCtrl,
                  decoration: const InputDecoration(
                      labelText: '추가 (이메일/닉네임)', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.person_add, color: color),
                onPressed: () async {
                  final key = _keyCtrl.text.trim();
                  if (key.isEmpty) return;
                  final r = await appState.addShareGroupMember(widget.groupId, key);
                  if (!mounted) return;
                  if (r['success'] != true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(r['message']?.toString() ?? '추가 실패')));
                  } else {
                    _keyCtrl.clear();
                    _load();
                  }
                },
              ),
            ]),
            const Divider(),
            if (_loading)
              const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
            else if (_members.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('멤버가 없습니다.'))
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _members.map((m) {
                    final mid = m['memberId']?.toString() ?? '';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(m['memberName']?.toString() ?? mid),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                        onPressed: () async {
                          await appState.removeShareGroupMember(widget.groupId, mid);
                          _load();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      ],
    );
  }
}
