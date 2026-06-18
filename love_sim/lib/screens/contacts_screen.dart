import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:love_sim/main.dart';
import 'package:love_sim/providers/app_provider.dart';
import 'package:love_sim/screens/character_profile_screen.dart';
import 'package:love_sim/screens/chat_screen.dart';
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
            final fullChars = script.characters.where((c) => c.fullCharacter).toList();
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

                return Container(
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
                                        Text(displayName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimaryDark)),
                                        if (remark.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Text(char.basic.name, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lastMsg.isNotEmpty ? lastMsg : char.summary,
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
                );
              },
            );
          },
        ),
      ),
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
