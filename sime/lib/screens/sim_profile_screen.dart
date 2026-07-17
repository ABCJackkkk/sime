import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';
import 'package:sime/main.dart';
import 'package:sime/models/script.dart';
import 'package:sime/providers/app_provider.dart';
import 'package:sime/services/ranking_service.dart';

class SimProfileScreen extends StatelessWidget {
  const SimProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, app, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlayerCard(app, context),
                  const SizedBox(height: 12),
                  _buildDataLayerSection(app),
                  const SizedBox(height: 12),
                  _buildAffectionSection(app),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerCard(AppProvider app, BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(children: [
            GestureDetector(
              onTap: () => _editPlayerCard(context, app),
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF64D2FF)]), boxShadow: [BoxShadow(color: AppColors.accent.withAlpha(40), blurRadius: 16)]),
                child: Center(child: Text(app.userName.isNotEmpty ? app.userName.characters.first : '我', style: const TextStyle(color: CupertinoColors.white, fontSize: 26, fontWeight: FontWeight.w700))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(app.userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _editPlayerCard(context, app),
                    child: const Icon(CupertinoIcons.pencil, size: 14, color: AppColors.textTertiary),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  if (app.userGender.isNotEmpty) _tag(app.userGender),
                  if (app.userHeight.isNotEmpty) _tag(app.userHeight),
                  if (app.userBirthday.isNotEmpty) _tag(app.userBirthday),
                ]),
              ]),
            ),
          ]),
          if (app.userBio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0x08FFFFFF), borderRadius: BorderRadius.circular(10)), child: Text(app.userBio, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5))),
          ],
          if (app.userAppearance.isNotEmpty || app.userPersonality.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (app.userPersonality.isNotEmpty) Expanded(child: _infoCard('性格', app.userPersonality)),
              if (app.userAppearance.isNotEmpty) ...[const SizedBox(width: 8), Expanded(child: _infoCard('外貌', app.userAppearance))],
            ]),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0x08FFFFFF), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
      ]),
    );
  }

  void _editPlayerCard(BuildContext context, AppProvider app) {
    final nameCtrl = TextEditingController(text: app.userName);
    final genderCtrl = TextEditingController(text: app.userGender);
    final heightCtrl = TextEditingController(text: app.userHeight);
    final birthdayCtrl = TextEditingController(text: app.userBirthday);
    final bioCtrl = TextEditingController(text: app.userBio);
    final appearanceCtrl = TextEditingController(text: app.userAppearance);
    final personalityCtrl = TextEditingController(text: app.userPersonality);

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(color: AppColors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          child: Column(children: [
            Row(children: [
              CupertinoButton(child: const Text('取消', style: TextStyle(color: AppColors.textTertiary)), onPressed: () => Navigator.pop(context)),
              const Spacer(),
              const Text('编辑角色卡', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
              const Spacer(),
              CupertinoButton(child: const Text('保存', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)), onPressed: () {
                app.setUserName(nameCtrl.text.trim());
                app.setUserGender(genderCtrl.text.trim());
                app.setUserHeight(heightCtrl.text.trim());
                app.setUserBirthday(birthdayCtrl.text.trim());
                app.setUserBio(bioCtrl.text.trim());
                app.setUserAppearance(appearanceCtrl.text.trim());
                app.setUserPersonality(personalityCtrl.text.trim());
                Navigator.pop(context);
              }),
            ]),
            SizedBox(height: 1, child: Container(color: AppColors.border)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _editField('名字', nameCtrl),
                  const SizedBox(height: 12),
                  _editField('性别', genderCtrl),
                  const SizedBox(height: 12),
                  _editField('身高', heightCtrl),
                  const SizedBox(height: 12),
                  _editField('生日', birthdayCtrl),
                  const SizedBox(height: 12),
                  _editField('一句话简介', bioCtrl, maxLines: 2),
                  const SizedBox(height: 12),
                  _editField('外貌描述', appearanceCtrl, maxLines: 2),
                  const SizedBox(height: 12),
                  _editField('性格描述', personalityCtrl, maxLines: 2),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
      const SizedBox(height: 6),
      CupertinoTextField(
        controller: ctrl,
        placeholder: '输入$label...',
        placeholderStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
        maxLines: maxLines,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0x08FFFFFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border, width: 0.5)),
        style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 14),
      ),
    ]);
  }

  Widget _buildDataLayerSection(AppProvider app) {
    final dl = app.script?.dataLayer;
    if (dl == null || (dl.stats.isEmpty && dl.grades.isEmpty)) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (dl.stats.isNotEmpty) ...[
        _buildStatsCard(app, dl),
        const SizedBox(height: 12),
      ],
      if (dl.grades.isNotEmpty) ...[
        _buildGradesCard(app, dl),
        const SizedBox(height: 12),
      ],
      if (dl.ranking.events.isNotEmpty) _buildRankingCard(app, dl),
    ]);
  }

  Widget _buildStatsCard(AppProvider app, GameDataLayer dl) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: AppColors.accent.withAlpha(25)), child: const Icon(CupertinoIcons.chart_bar_alt_fill, size: 14, color: AppColors.accent)),
          const SizedBox(width: 10),
          const Text('属性', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
        ]),
        const SizedBox(height: 14),
        ...dl.stats.map((s) => _buildStatRow(app.playerStats[s.id] ?? s.initial, s.name, s.max)),
      ]),
    );
  }

  Widget _buildStatRow(double value, String name, double maxVal) {
    final pct = (value / maxVal).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        Row(children: [
          Text(name, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
        ]),
        const SizedBox(height: 4),
        Container(
          height: 4,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: AppColors.border.withAlpha(50)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct,
            child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF64D2FF)]))),
          ),
        ),
      ]),
    );
  }

  Widget _buildGradesCard(AppProvider app, GameDataLayer dl) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: AppColors.warning.withAlpha(25)), child: const Icon(CupertinoIcons.book_fill, size: 14, color: AppColors.warning)),
          const SizedBox(width: 10),
          const Text('成绩', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
        ]),
        const SizedBox(height: 14),
        ...dl.grades.map((g) {
          final val = app.playerGrades[g.id] ?? g.initial;
          final pct = (val / g.max).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(children: [
              Row(children: [
                Text(g.name, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const Spacer(),
                Text(val.toStringAsFixed(0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
              ]),
              const SizedBox(height: 4),
              Container(
                height: 4,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: AppColors.border.withAlpha(50)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct,
                  child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: const LinearGradient(colors: [AppColors.warning, Color(0xFFFFB74D)]))),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildRankingCard(AppProvider app, GameDataLayer dl) {
    final rs = app.rankingService;
    final latest = rs?.latestRank;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: AppColors.success.withAlpha(25)), child: const Icon(CupertinoIcons.star_fill, size: 14, color: AppColors.success)),
          const SizedBox(width: 10),
          const Text('排名', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
          const Spacer(),
          Text('共${dl.ranking.totalStudents}人', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ]),
        const SizedBox(height: 14),
        if (latest != null) ...[
          _buildPlayerRankRow(latest),
          const SizedBox(height: 10),
          ...latest.charRanks.map((cr) => _buildCharRankRow(cr, app)),
          const SizedBox(height: 10),
          _buildExamSchedule(dl),
        ] else ...[
          _buildExamSchedule(dl),
        ],
      ]),
    );
  }

  Widget _buildPlayerRankRow(RankRecord latest) {
    final rankDiff = latest.prevRank > 0 ? latest.prevRank - latest.playerRank : 0;
    final diffColor = rankDiff > 0 ? AppColors.success : (rankDiff < 0 ? AppColors.error : AppColors.textTertiary);
    final diffIcon = rankDiff > 0 ? CupertinoIcons.arrow_up : (rankDiff < 0 ? CupertinoIcons.arrow_down : CupertinoIcons.minus);
    final diffText = rankDiff > 0 ? '+$rankDiff' : (rankDiff < 0 ? '$rankDiff' : '-');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.accent.withAlpha(15), border: Border.all(color: AppColors.accent.withAlpha(40))),
      child: Row(children: [
        Container(width: 22, height: 22, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: AppColors.accent.withAlpha(30)), child: Center(child: Text(latest.playerRank.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accent)))),
        const SizedBox(width: 10),
        const Text('你', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
        const Spacer(),
        Text(latest.playerTotalScore.toStringAsFixed(0), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Text(latest.eventName, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
        const SizedBox(width: 8),
        Icon(diffIcon, size: 12, color: diffColor),
        Text(diffText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: diffColor)),
      ]),
    );
  }

  Widget _buildCharRankRow(CharRankEntry cr, AppProvider app) {
    final char = app.getCharacter(cr.charId);
    final name = char?.basic.name ?? cr.charName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(width: 22, height: 22, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: AppColors.textTertiary.withAlpha(30)), child: Center(child: Text(cr.rank.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)))),
        const SizedBox(width: 10),
        Text(name, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text(cr.totalScore.toStringAsFixed(0), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ]),
    );
  }

  Widget _buildExamSchedule(GameDataLayer dl) {
    final day = dl.memory.lastRankingDay;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 4),
      ...dl.ranking.events.map((evt) {
        final nextIn = evt.intervalDays > 0 && day > 0 ? (evt.intervalDays - (day % evt.intervalDays)) : evt.intervalDays;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.textTertiary.withAlpha(100))),
            const SizedBox(width: 8),
            Text(evt.name, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            const Spacer(),
            Text(day > 0 ? '距下次${nextIn}天' : '第${evt.intervalDays}天首次', style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          ]),
        );
      }),
    ]);
  }

  Widget _tag(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.accent.withAlpha(20)),
      child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.accent)),
    );
  }

  Widget _buildAffectionSection(AppProvider app) {
    final script = app.script;
    final chars = script?.characters.where((c) => c.fullCharacter).toList() ?? [];
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: AppColors.error.withAlpha(25)), child: const Icon(CupertinoIcons.heart_fill, size: 14, color: AppColors.error)),
          const SizedBox(width: 10),
          const Text('好感度', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark)),
        ]),
        const SizedBox(height: 14),
        if (chars.isEmpty)
          const Text('暂无角色', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))
        else
          ...chars.map((char) => _buildAffectionRow(app, char)),
      ]),
    );
  }

  Widget _buildAffectionRow(AppProvider app, Character char) {
    final charId = char.basic.id;
    final name = app.getCharDisplayName(charId);
    final affection = app.getAffection(charId);
    final pct = affection / 100.0;
    final color = _affectionColor(affection);
    final stateLabel = app.getRelationStateLabel(charId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF64D2FF)])), child: Center(child: Text(name.isNotEmpty ? name.characters.first : '?', style: const TextStyle(color: CupertinoColors.white, fontSize: 14, fontWeight: FontWeight.w600)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimaryDark)),
            if (stateLabel.isNotEmpty) Text(stateLabel, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          ])),
          Text(affection.toStringAsFixed(2), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ]),
        const SizedBox(height: 6),
        Container(
          height: 5,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: AppColors.border.withAlpha(50)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct.clamp(0.0, 1.0),
            child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), gradient: LinearGradient(colors: [color, color.withAlpha(180)]))),
          ),
        ),
      ]),
    );
  }

  Color _affectionColor(double val) {
    if (val < 20) return AppColors.error;
    if (val < 40) return const Color(0xFFFF9800);
    if (val < 60) return const Color(0xFF64D2FF);
    if (val < 80) return AppColors.accent;
    return const Color(0xFF9C27B0);
  }
}