import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:love_sim/main.dart';
import 'package:love_sim/models/script.dart';
import 'package:love_sim/providers/app_provider.dart';
import 'package:love_sim/services/save_service.dart';

class ChatScreen extends StatefulWidget {
  final String characterId;
  const ChatScreen({super.key, required this.characterId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().markCharRead(widget.characterId);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.background,
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        middle: Consumer<AppProvider>(
          builder: (context, app, _) {
            final char = app.getCharacter(widget.characterId);
            final unread = app.hasUnread(widget.characterId);
            final img = app.getCharImageBytes(widget.characterId);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (img != null) ...[
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(img, width: 28, height: 28, fit: BoxFit.cover)),
                  const SizedBox(width: 8),
                ],
                Text(char?.basic.name ?? '聊天', style: const TextStyle(color: AppColors.textPrimaryDark)),
                if (unread) ...[
                  const SizedBox(width: 6),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error)),
                ],
              ],
            );
          },
        ),
      ),
      child: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, app, _) {
            final messages = app.getChatHistory(widget.characterId);

            return Column(
              children: [
                Expanded(
                  child: messages.isEmpty && !app.isChatLoading(widget.characterId)
                      ? Center(child: Text('开始对话吧', style: TextStyle(color: AppColors.textTertiary.withAlpha(180), fontSize: 15)))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length + (app.isChatLoading(widget.characterId) ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < messages.length) {
                              final msg = messages[index];
                              final isPlayer = msg.senderId == 'player';
                              final isRead = isPlayer && app.isPlayerMessageRead(widget.characterId, index);
                              return _buildBubble(msg, isPlayer, isRead);
                            }
                            return _buildTypingIndicator();
                          },
                        ),
                ),
                _buildInputBar(app),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg, bool isPlayer, bool isRead) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isPlayer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isPlayer ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isPlayer) ...[
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accent, Color(0xFF64D2FF)])),
                  child: Center(child: Text(msg.senderName.isNotEmpty ? msg.senderName.characters.first : '?', style: const TextStyle(color: CupertinoColors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isPlayer ? AppColors.accent.withAlpha(40) : const Color(0x0FFFFFFF),
                    borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: isPlayer ? const Radius.circular(18) : const Radius.circular(4), bottomRight: isPlayer ? const Radius.circular(4) : const Radius.circular(18)),
                    border: Border.all(color: isPlayer ? AppColors.accent.withAlpha(50) : AppColors.border, width: 0.5),
                  ),
                  child: Text(msg.content, style: TextStyle(fontSize: 15, color: isPlayer ? AppColors.accent : AppColors.textPrimaryDark, height: 1.4)),
                ),
              ),
              if (isPlayer) ...[
                const SizedBox(width: 8),
                Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.textTertiary.withAlpha(30)), child: const Icon(CupertinoIcons.person_fill, size: 16, color: AppColors.textTertiary)),
              ],
            ],
          ),
          if (isPlayer && isRead)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 44),
              child: Text('已读', style: TextStyle(fontSize: 11, color: AppColors.textTertiary.withAlpha(160))),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar(AppProvider app) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      decoration: const BoxDecoration(color: Color(0x0AFFFFFF), border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
      child: Row(
        children: [
          CupertinoButton(
            onPressed: () => _showGiftSheet(context, app),
            padding: const EdgeInsets.all(8), minSize: 0,
            borderRadius: BorderRadius.circular(20),
            color: AppColors.accent.withAlpha(30),
            child: const Icon(CupertinoIcons.add, size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoTextField(
              controller: _textController,
              placeholder: '输入消息...',
              placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0x08FFFFFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border, width: 0.5)),
              style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 15),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            onPressed: () {
              final text = _textController.text.trim();
              if (text.isEmpty) return;
              app.sendMessage(widget.characterId, text);
              _textController.clear();
              _scrollToBottom();
            },
            padding: const EdgeInsets.all(10), minSize: 0,
            borderRadius: BorderRadius.circular(20), color: AppColors.accent,
            child: const Icon(CupertinoIcons.paperplane_fill, size: 18, color: CupertinoColors.white),
          ),
        ],
      ),
    );
  }

  void _showGiftSheet(BuildContext context, AppProvider app) {
    final script = app.script;
    List<ShopItem> ownedItems = [];
    if (script != null) {
      for (final item in [...script.items.gifts, ...script.items.shopItems]) {
        if (app.hasItem(item.id)) {
          ownedItems.add(item);
        }
      }
    }

    if (ownedItems.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('暂无物品'),
          content: const Text('去商店购买一些礼物吧'),
          actions: [CupertinoDialogAction(child: const Text('好的'), onPressed: () => Navigator.pop(context))],
        ),
      );
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('赠送物品', style: TextStyle(color: AppColors.textPrimaryDark)),
        message: const Text('选择一个物品送给对方'),
        actions: ownedItems.map((item) {
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              app.sendGift(widget.characterId, item);
              _scrollToBottom();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.gift_fill, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(item.name, style: const TextStyle(color: AppColors.textPrimaryDark)),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: AppColors.accent)),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accent, Color(0xFF64D2FF)])),
            child: const Center(child: Icon(CupertinoIcons.ellipsis, size: 18, color: CupertinoColors.white)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0x0FFFFFFF),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18)),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: _TypingDots(),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [0, 1, 2].map((i) {
            final delay = i * 0.2;
            final opacity = ((t - delay) % 1.0).clamp(0.0, 1.0) < 0.5 ? 0.3 : 1.0;
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: opacity,
                child: Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.textTertiary)),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
