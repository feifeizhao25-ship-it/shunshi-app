// 顺时 AI对话页面 — 国内版
// 设计理念：呼吸感，大留白，柔和

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/api_service.dart';
import '../../data/services/voice_service.dart';
import 'package:image_picker/image_picker.dart';

/// 聊天页面 - 核心对话界面 (国内版)
class ChatPage extends ConsumerStatefulWidget {
  final String? conversationId;

  const ChatPage({super.key, this.conversationId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;

  // 语音输入
  final VoiceService _voiceService = VoiceService();
  bool _isListening = false;
  bool _voiceInitialized = false;

  // 图片
  final List<String> _selectedImagePaths = [];

  // 引导卡片
  bool _showGuideCards = false;
  int _guidePage = 0;

  // 消息列表
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      content: '你好呀，我是顺时～\n有什么想聊聊的吗？',
      isUser: false,
      time: DateTime.now(),
    ),
  ];

  // 快捷问题
  final List<String> _quickQuestions = [
    '今天吃什么好',
    '最近睡不好怎么办',
    '适合做什么运动',
  ];

  @override
  void initState() {
    super.initState();
    _initVoice();
    _checkGuideCards();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initVoice() async {
    final ok = await _voiceService.initialize();
    if (mounted) setState(() => _voiceInitialized = ok);
  }

  Future<void> _checkGuideCards() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_guide_cards_v2') ?? false;
    if (!hasSeen && mounted) {
      setState(() => _showGuideCards = true);
    }
  }

  Future<void> _dismissGuideCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_guide_cards_v2', true);
    if (mounted) setState(() => _showGuideCards = false);
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImagePaths.isEmpty) return;

    // 重置语音
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
    }

    setState(() {
      _isLoading = true;
      _messages.add(_ChatMessage(
        content: text.isEmpty ? '[图片]' : text,
        isUser: true,
        time: DateTime.now(),
        imagePaths: _selectedImagePaths.isNotEmpty ? List.from(_selectedImagePaths) : null,
      ));
    });

    _messageController.clear();
    _selectedImagePaths.clear();
    _voiceService.reset();
    _scrollToBottom();

    try {
      final apiService = ApiService();
      final result = await apiService.chat(userId: 'user_001', message: text);
      final data = result['data'] ?? result;
      final aiResponse = data['message'] ?? data['text'] ?? '抱歉，我现在有点累，稍后再试试吧～';

      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          content: aiResponse,
          isUser: false,
          time: DateTime.now(),
        ));
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          content: '抱歉，连接出了问题。请检查网络后重试～',
          isUser: false,
          time: DateTime.now(),
        ));
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _voiceService.stopListening();
      if (_voiceService.lastWords.isNotEmpty && mounted) {
        setState(() => _messageController.text = _voiceService.lastWords);
      }
      setState(() => _isListening = false);
    } else {
      final ok = await _voiceService.startListening(
        onResult: (text) {
          if (mounted) setState(() => _messageController.text = text);
        },
      );
      if (ok) setState(() => _isListening = true);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
      if (image != null) setState(() => _selectedImagePaths.add(image.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8F5),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '顺时',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400, // 轻标题，不粗体
            color: Color(0xFF2C2C2C),
          ),
        ),
        centerTitle: true,
      ),
      body: _showGuideCards
          ? _buildGuideOverlay()
          : Column(
              children: [
                // 消息列表
                Expanded(child: _buildMessageList()),
                // 图片预览
                if (_selectedImagePaths.isNotEmpty) _buildImagePreview(),
                // 快捷问题chips
                if (_messages.length <= 1 && !_isLoading) _buildQuickQuestions(),
                // 输入区域
                _buildInputArea(),
              ],
            ),
    );
  }

  // ──────────────────────────────────────────────
  // 首次引导 — PageView 3张
  // ──────────────────────────────────────────────

  Widget _buildGuideOverlay() {
    final guideCards = [
      _GuideCardData(
        emoji: '💡',
        title: '养生问答',
        description: '任何关于饮食、运动、睡眠的问题\n都可以问我',
        color: const Color(0xFFFFF8E1),
      ),
      _GuideCardData(
        emoji: '🍵',
        title: '试试说',
        description: '"今天吃什么好"\n"最近睡不好怎么办"',
        color: const Color(0xFFF1F8E9),
      ),
      _GuideCardData(
        emoji: '❤️',
        title: '我了解你',
        description: '我会记住你的偏好和习惯\n给你更贴心的建议',
        color: const Color(0xFFFCE4EC),
      ),
    ];

    final controller = PageController();

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Expanded(
            child: PageView.builder(
              controller: controller,
              itemCount: guideCards.length,
              onPageChanged: (index) => setState(() => _guidePage = index),
              itemBuilder: (context, index) {
                final card = guideCards[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      Text(card.emoji, style: const TextStyle(fontSize: 72)),
                      const SizedBox(height: 32),
                      Text(
                        card.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        card.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B6B6B),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // 页码指示
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(guideCards.length, (index) {
                return Container(
                  width: _guidePage == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _guidePage == index
                        ? const Color(0xFF4A7C6F)
                        : const Color(0xFFE8E5E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          // 按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _dismissGuideCards,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A7C6F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _guidePage == guideCards.length - 1 ? '开始聊天' : '继续',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          // 跳过
          if (_guidePage < guideCards.length - 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: TextButton(
                onPressed: _dismissGuideCards,
                child: const Text('跳过', style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 消息列表
  // ──────────────────────────────────────────────

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _TypingIndicator(),
          );
        }
        final msg = _messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16), // 消息间距至少16dp
          child: _MessageBubble(message: msg),
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  // 图片预览
  // ──────────────────────────────────────────────

  Widget _buildImagePreview() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImagePaths.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index < _selectedImagePaths.length) {
            final path = _selectedImagePaths[index];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(path), width: 64, height: 64, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedImagePaths.removeAt(index)),
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          }
          return GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE8E5E0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_photo_alternate, color: Color(0xFF9B9B9B)),
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 快捷问题 — 3个Chip
  // ──────────────────────────────────────────────

  Widget _buildQuickQuestions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _quickQuestions.map((q) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  _messageController.text = q;
                  _sendMessage();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE8E5E0)),
                  ),
                  child: Text(
                    q,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 输入区域 — 圆角24，高度48
  // ──────────────────────────────────────────────

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8F5),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 输入框
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE8E5E0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2C)),
                        decoration: const InputDecoration(
                          hintText: '输入消息...',
                          hintStyle: TextStyle(color: Color(0xFFCCCCCC), fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    // 语音按钮
                    if (_voiceInitialized)
                      GestureDetector(
                        onTap: _toggleVoice,
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? const Color(0xFFD4726A) : const Color(0xFF9B9B9B),
                            size: 22,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 发送按钮
            GestureDetector(
              onTap: _isLoading ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isLoading ? const Color(0xFFE8E5E0) : const Color(0xFF4A7C6F),
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Message Bubble
// ═══════════════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _buildUserBubble(context);
    }
    return _buildAIBubble(context);
  }

  /// 用户消息：右侧，浅灰背景，compact
  Widget _buildUserBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF4A7C6F).withValues(alpha: 0.3), // primaryLight.withValues(alpha: 0.3)
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(0), // 右下角0
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.imagePaths != null && message.imagePaths!.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.imagePaths!.map((path) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(path), width: 120, height: 120, fit: BoxFit.cover),
                    );
                  }).toList(),
                ),
              if (message.imagePaths != null && message.imagePaths!.isNotEmpty)
                const SizedBox(height: 8),
              Text(
                message.content,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF2C2C2C),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${message.time.hour}:${message.time.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// AI消息：左侧，白色，更大，圆角16（左下角0）
  Widget _buildAIBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(0), // 左上角0（靠近头像方向）
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 检测建议卡内容
              ..._parseContent(message.content),
              const SizedBox(height: 4),
              Text(
                '${message.time.hour}:${message.time.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFCCCCCC)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 解析AI消息内容，提取建议卡
  List<Widget> _parseContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    final textLines = <String>[];
    bool inSuggestion = false;

    for (final line in lines) {
      // 检测建议卡标记（🌿 或 💡 开头的行）
      if (line.trimLeft().startsWith('🌿') || line.trimLeft().startsWith('💡')) {
        // 先flush前面的文字
        if (textLines.isNotEmpty) {
          widgets.add(Text(
            textLines.join('\n'),
            style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2C), height: 1.6),
          ));
          widgets.add(const SizedBox(height: 12));
          textLines.clear();
        }
        widgets.add(_SuggestionEmbed(
          icon: line.trimLeft().startsWith('🌿') ? '🌿' : '💡',
          title: line.replaceFirst(RegExp(r'^\s*[🌿💡]\s*'), ''),
        ));
        widgets.add(const SizedBox(height: 4));
        inSuggestion = true;
      } else if (inSuggestion && line.trim().isNotEmpty) {
        // 建议卡后的描述行
        // 追加到建议卡
      } else {
        textLines.add(line);
        inSuggestion = false;
      }
    }

    // flush剩余文字
    if (textLines.isNotEmpty) {
      widgets.add(Text(
        textLines.join('\n'),
        style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2C), height: 1.6),
      ));
    }

    if (widgets.isEmpty) {
      widgets.add(Text(
        content,
        style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2C), height: 1.6),
      ));
    }

    return widgets;
  }
}

// ═══════════════════════════════════════════════
// 嵌入式建议卡
// ═══════════════════════════════════════════════

class _SuggestionEmbed extends StatelessWidget {
  final String icon;
  final String title;

  const _SuggestionEmbed({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4A7C6F).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A7C6F).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, color: Color(0xFF2C2C2C)),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF9B9B9B)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Typing Indicator
// ═══════════════════════════════════════════════

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(0),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), offset: const Offset(0, 2), blurRadius: 8),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final delay = index * 0.2;
                final value = ((_controller.value + delay) % 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A7C6F).withValues(alpha: 0.3 + value * 0.5),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Data Model
// ═══════════════════════════════════════════════

class _ChatMessage {
  final String content;
  final bool isUser;
  final DateTime time;
  final List<String>? imagePaths;

  _ChatMessage({
    required this.content,
    required this.isUser,
    required this.time,
    this.imagePaths,
  });
}

class _GuideCardData {
  final String emoji;
  final String title;
  final String description;
  final Color color;

  const _GuideCardData({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
  });
}
