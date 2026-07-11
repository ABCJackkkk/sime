import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:love_sim/main.dart';
import 'package:love_sim/models/script.dart';
import 'package:love_sim/providers/app_provider.dart';
import 'package:love_sim/screens/character_profile_screen.dart';
import 'package:love_sim/screens/chat_screen.dart';
import 'package:love_sim/services/save_service.dart';
import 'package:love_sim/widgets/reactive_avatar.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, app, _) {
            final script = app.script;
            if (script == null) {
              return Center(child: Text('请先加载剧本', style: TextStyle(color: AppColors.textTertiary.withAlpha(180), fontSize: 15)));
            }
            final fullChars = script.characters.where((c) => c.fullCharacter && app.isDiscovered(c.basic.id)).toList();
            if (fullChars.isEmpty) {
              return Center(child: Text('暂无角色数据', style: TextStyle(color: AppColors.textTertiary.withAlpha(180), fontSize: 15)));
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: fullChars.length,
              separatorBuilder: (_, __) => Container(height: 0.5, margin: const EdgeInsets.only(left: 76), color: AppColors.border),
              itemBuilder: (context, index) {
                final char = fullChars[index];
                final charId = char.basic.id;
                final displayName = app.getCharDisplayName(charId);
                final remark = app.getCharRemarkName(charId);
                final lastMsg = app.getCharLastMessage(charId);
                final lastTime = app.getCharLastMessageTime(charId);
                final unread = app.unreadCount(charId);
                final hasUnread = app.hasUnread(charId);
                final charImg = app.getCharImageBytes(charId);
                final affect = app.affectionStates[charId] ?? 50.0;
                final recentEvent = app.segmentEventTypes.isNotEmpty ? app.segmentEventTypes.last : null;

                return GestureDetector(
                  onLongPress: () {
                    app.markCharRead(charId);
                    _showChatHistory(context, app, charId, displayName, charImg, affect, recentEvent);
                  },
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            app.markCharRead(charId);
                            Navigator.of(context).push(CupertinoPageRoute(builder: (_) => CharacterProfileScreen(characterId: charId)));
                          },
                          child: Stack(
                            children: [
                              Hero(
                                tag: 'chat_avatar_$charId',
                                child: ReactiveAvatar(
                                  size: 52, borderRadius: 12, affection: affect, recentEventType: recentEvent,
                                  child: Container(
                                    width: 52, height: 52,
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.accent.withAlpha(40)),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: charImg != null
                                          ? Image.memory(charImg, width: 52, height: 52, fit: BoxFit.cover)
                                          : Center(child: Text(displayName.isNotEmpty ? displayName.characters.first : '?', style: const TextStyle(color: AppColors.accent, fontSize: 22, fontWeight: FontWeight.w700))),
                                    ),
                                  ),
                                ),
                              ),
                              if (hasUnread)
                                Positioned(top: -2, right: -2,
                                  child: Container(
                                    width: 20, height: 20,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.error, border: Border.all(color: AppColors.background, width: 2)),
                                    child: Center(child: Text('${unread > 99 ? '99+' : unread}', style: const TextStyle(color: CupertinoColors.white, fontSize: 10, fontWeight: FontWeight.w700))),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              app.markCharRead(charId);
                              Navigator.of(context).push(PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(characterId: charId),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
                                transitionDuration: const Duration(milliseconds: 250),
                              ));
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(displayName,
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimaryDark),
                                              overflow: TextOverflow.ellipsis, maxLines: 1,
                                            ),
                                          ),
                                          if (remark.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text(char.basic.name, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastMsg.isNotEmpty ? lastMsg : char.charIntro,
                                        style: TextStyle(fontSize: 13, color: hasUnread ? AppColors.textPrimaryDark.withAlpha(200) : AppColors.textTertiary, height: 1.3),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (lastTime != null)
                                      Text(_formatTime(lastTime), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                    const SizedBox(height: 6),
                                    if (hasUnread)
                                      Container(
                                        width: 18, height: 18,
                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error),
                                        child: Center(child: Text('$unread', style: const TextStyle(color: CupertinoColors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showChatHistory(BuildContext context, AppProvider app, String charId, String displayName, Uint8List? charImg, double affection, String? recentEvent) {
    final messages = app.getChatHistory(charId);
    final scrollCtrl = ScrollController();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollCtrl.hasClients) {
            scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
          }
        });
        return Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.65),
        decoration: const BoxDecoration(color: Color(0xFF1A1A1E), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: AppColors.textTertiary.withAlpha(80))),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 20),
                ReactiveAvatar(
                  size: 36, borderRadius: 10, affection: affection, recentEventType: recentEvent,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.accent.withAlpha(40)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: charImg != null ? Image.memory(charImg, width: 36, height: 36, fit: BoxFit.cover) : Center(child: Text(displayName.characters.first, style: const TextStyle(color: AppColors.accent, fontSize: 16))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('与 $displayName 的对话记录', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
                const Spacer(),
                CupertinoButton(
                  padding: const EdgeInsets.all(8), minSize: 0,
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(PageRouteBuilder(
                      pageBuilder: (c, a, sa) => ChatScreen(characterId: charId),
                      transitionsBuilder: (c, a, sa, child) => FadeTransition(opacity: a, child: child),
                      transitionDuration: const Duration(milliseconds: 250),
                    ));
                  },
                  child: const Text('进入对话', style: TextStyle(fontSize: 13, color: AppColors.accent)),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(color: AppColors.border, height: 1),
            if (messages.isEmpty)
              const Expanded(child: Center(child: Text('暂无对话记录', style: TextStyle(fontSize: 14, color: AppColors.textTertiary))))
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isPlayer = msg.senderId == 'player';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: isPlayer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: isPlayer ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              Text(isPlayer ? '我' : msg.senderName, style: TextStyle(fontSize: 11, color: AppColors.textTertiary.withAlpha(180))),
                              const SizedBox(width: 6),
                              Text(_formatTime(msg.timestamp), style: TextStyle(fontSize: 10, color: AppColors.textTertiary.withAlpha(120))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.7),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isPlayer ? AppColors.accent.withAlpha(30) : const Color(0x0AFFFFFF),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12), topRight: const Radius.circular(12),
                                bottomLeft: isPlayer ? const Radius.circular(12) : const Radius.circular(4),
                                bottomRight: isPlayer ? const Radius.circular(4) : const Radius.circular(12),
                              ),
                              border: Border.all(color: isPlayer ? AppColors.accent.withAlpha(50) : AppColors.border, width: 0.5),
                            ),
                            child: Text(msg.content, style: TextStyle(fontSize: 14, color: isPlayer ? AppColors.accent : AppColors.textPrimaryDark, height: 1.4)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.month}/${t.day}';
  }
}
