import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state_provider.dart';

/// 'AI 셀' 대화 화면.
/// 주제 안에서 AI와 대화하고, 재방문 시 서버에 저장된 과거 대화를 불러와 이어간다.
/// 대화 이어가기(메모리)는 서버가 담당하므로(하이브리드: 최근N턴+러닝요약),
/// 이 화면은 서버가 주는 메시지를 표시하고 새 메시지를 보내기만 한다.
class AiChatScreen extends StatefulWidget {
  final int chatId;
  final String title;
  final String topic;

  const AiChatScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.topic = '',
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = []; // {role, content}
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🤖 [AI셀] 화면 진입 - chatId: ${widget.chatId}, 주제: ${widget.topic}');
    _loadHistory();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final appState = context.read<AppStateProvider>();
    final msgs = await appState.aiChatMessages(widget.chatId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _messages
        ..clear()
        ..addAll((msgs ?? const []).map((m) => {
              'role': m['role']?.toString() ?? 'assistant',
              'content': m['content']?.toString() ?? '',
            }));
    });
    _jumpToBottom();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    debugPrint('🤖 [AI셀] 메시지 전송 - chatId: ${widget.chatId}, 길이: ${text.length}');
    _input.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _sending = true; // AI 응답 대기(타이핑 인디케이터)
    });
    _jumpToBottom();

    final appState = context.read<AppStateProvider>();
    final res = await appState.sendAiChatMessage(widget.chatId, text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (res != null && res['assistantMessage'] != null) {
        final a = res['assistantMessage'] as Map;
        _messages.add({
          'role': 'assistant',
          'content': a['content']?.toString() ?? '',
        });
      } else {
        _messages.add({
          'role': 'assistant',
          'content': '(응답을 받지 못했어요. 네트워크를 확인하고 다시 시도해 주세요.)',
        });
      }
    });
    _jumpToBottom();
  }

  void _jumpToBottom() {
    // reverse:true 리스트에선 맨 아래(최신)가 offset 0. 새 메시지 전송 후 최신으로 붙인다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(widget.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
            if (widget.topic.isNotEmpty)
              Text('주제 · ${widget.topic}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _emptyHint(color)
                    : ListView.builder(
                        controller: _scroll,
                        // 카카오톡 방식: 최신 메시지가 항상 맨 아래(입력창 바로 위)에 오고,
                        // 진입 시 자동으로 최신이 보이도록 역방향 리스트를 쓴다(index 0 = 맨 아래).
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          // 전송 중이면 맨 아래(i=0)에 'AI 입력 중' 버블을 둔다.
                          if (_sending && i == 0) return _typingBubble(color);
                          final idx = _messages.length - 1 - (_sending ? i - 1 : i);
                          final m = _messages[idx];
                          final isUser = m['role'] == 'user';
                          return _bubble(m['content']?.toString() ?? '', isUser, color);
                        },
                      ),
          ),
          _inputBar(color),
        ],
      ),
    );
  }

  Widget _emptyHint(Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: color.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              widget.topic.isNotEmpty
                  ? "'${widget.topic}' 주제로 AI와 대화를 시작해 보세요."
                  : 'AI와 대화를 시작해 보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text('다시 들어와도 대화가 이어져요.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _bubble(String text, bool isUser, Color color) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? color : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: SelectableText(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF1a2233),
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _typingBubble(Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
            const SizedBox(width: 10),
            Text('AI가 입력 중…',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _inputBar(Color color) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                enabled: !_sending,
                decoration: InputDecoration(
                  hintText: _sending ? 'AI 응답을 기다리는 중…' : '메시지를 입력하세요',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: _sending ? Colors.grey.shade400 : color,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _send,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_upward, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
