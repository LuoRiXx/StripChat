import 'dart:async';
import 'package:flutter/material.dart';
import '../models/model_data.dart';
import '../services/api_service.dart';

class ChatWidget extends StatefulWidget {
  final ModelData model;

  const ChatWidget({super.key, required this.model});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  Timer? _pollTimer;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadChatMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadChatMessages();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChatMessages() async {
    final api = ApiService();
    final messages = await api.getChatMessages(widget.model.id);

    if (!mounted) return;

    if (messages.isNotEmpty) {
      setState(() {
        _isConnected = true;
        _messages.clear();
        _messages.add(ChatMessage(
          username: '系统',
          message: '欢迎来到 ${widget.model.username} 的直播间',
          timestamp: DateTime.now(),
          isSystem: true,
        ));
        for (final msg in messages) {
          final details = msg['details'] as Map<String, dynamic>? ?? {};
          final userData = msg['userData'] as Map<String, dynamic>? ?? {};
          final body = details['body'] ?? '';
          final user = userData['username'] ?? '匿名';
          if (body.toString().isNotEmpty) {
            _messages.add(ChatMessage(
              username: user.toString(),
              message: body.toString(),
              timestamp: DateTime.tryParse(msg['createdAt'] ?? '') ??
                  DateTime.now(),
            ));
          }
        }
      });
      _scrollToBottom();
    } else if (_messages.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          username: '系统',
          message: '欢迎来到 ${widget.model.username} 的直播间',
          timestamp: DateTime.now(),
          isSystem: true,
        ));
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        username: 'jijiang778',
        message: text,
        timestamp: DateTime.now(),
      ));
    });
    _messageController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline,
                    size: 16, color: Color(0xFFFF4081)),
                const SizedBox(width: 6),
                const Text(
                  '聊天',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.greenAccent : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      '暂无消息',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${msg.username}: ',
                                style: TextStyle(
                                  color: msg.isSystem
                                      ? Colors.amber
                                      : const Color(0xFFFF4081),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: msg.message,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '发送消息...',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF4081),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
