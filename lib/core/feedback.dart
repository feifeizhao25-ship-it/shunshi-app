import 'package:flutter/material.dart';

import '../data/network/api_client.dart';

/// 反馈服务
///
/// 修复说明：此前两个方法都只是 `await Future.delayed(1s)` 然后 `return true`，
/// 用户看到"感谢您的反馈！"但内容从未离开设备。现改为真实提交；
/// 失败返回 false，由 UI 展示"提交失败，请重试"。
class FeedbackService {
  /// 提交反馈
  static Future<bool> submitFeedback({
    required String content,
    String? contact,
    List<String>? screenshots,
  }) async {
    try {
      final response = await ApiClient().post(
        '/api/v1/feedback',
        data: {
          'content': content,
          if (contact != null && contact.isNotEmpty) 'contact': contact,
          if (screenshots != null && screenshots.isNotEmpty)
            'screenshots': screenshots,
        },
      );
      final code = response.statusCode ?? 0;
      return code >= 200 && code < 300;
    } catch (e) {
      debugPrint('Feedback submit failed: $e');
      return false;
    }
  }

  /// 提交应用评分
  ///
  /// 注意：这里只把评分回传自有后端。跳转 App Store / Play Store
  /// 需要接入 in_app_review 之类的插件，属于独立工作项。
  static Future<bool> rateApp({
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await ApiClient().post(
        '/api/v1/feedback/rating',
        data: {
          'rating': rating,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
      );
      final code = response.statusCode ?? 0;
      return code >= 200 && code < 300;
    } catch (e) {
      debugPrint('Rating submit failed: $e');
      return false;
    }
  }
}

/// 反馈弹窗组件
class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});
  
  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _controller = TextEditingController();
  final _contactController = TextEditingController();
  bool _isSubmitting = false;
  
  @override
  void dispose() {
    _controller.dispose();
    _contactController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('反馈建议'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '请描述您遇到的问题或建议...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(
                hintText: '联系方式 (可选)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('提交'),
        ),
      ],
    );
  }
  
  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入反馈内容')),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    final success = await FeedbackService.submitFeedback(
      content: _controller.text,
      contact: _contactController.text.isEmpty ? null : _contactController.text,
    );
    
    setState(() => _isSubmitting = false);
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '感谢您的反馈!' : '提交失败，请重试'),
        ),
      );
    }
  }
}

/// 评价弹窗
class RateAppDialog extends StatefulWidget {
  const RateAppDialog({super.key});
  
  @override
  State<RateAppDialog> createState() => _RateAppDialogState();
}

class _RateAppDialogState extends State<RateAppDialog> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('评价顺时'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
              icon: Icon(
                i < _rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 36,
              ),
              onPressed: () => setState(() => _rating = i + 1),
            )),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '评价内容 (可选)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _rating == 0 || _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('提交'),
        ),
      ],
    );
  }
  
  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final success = await FeedbackService.rateApp(
      rating: _rating,
      comment: _commentController.text.isEmpty ? null : _commentController.text,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.pop(context);
      // 此前无论成功与否都提示"感谢您的评价!"
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '感谢您的评价!' : '提交失败，请重试')),
      );
    }
  }
}
