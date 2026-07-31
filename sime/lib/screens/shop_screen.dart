import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sime/main.dart';
import 'package:sime/models/script.dart';
import 'package:sime/providers/app_provider.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, app, _) {
            final script = app.script;
            if (script == null) {
              return Center(
                child: Text(
                  '请先加载剧本',
                  style: TextStyle(
                    color: AppColors.textTertiary.withAlpha(180),
                    fontSize: 15,
                  ),
                ),
              );
            }

            final shopItems = script.items.shopItems;
            if (shopItems.isEmpty) {
              return Center(
                child: Text(
                  '商店暂无商品',
                  style: TextStyle(
                    color: AppColors.textTertiary.withAlpha(180),
                    fontSize: 15,
                  ),
                ),
              );
            }

            final gold = app.currencies['gold'] ?? 0;

            return Column(
              children: [
                _buildBalanceBar(gold),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: shopItems.length,
                    itemBuilder: (context, index) {
                      final item = shopItems[index];
                      return _buildShopCard(context, item, gold, app);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBalanceBar(int gold) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      borderRadius: 0,
      opacity: 0.06,
      child: Row(
        children: [
          const Icon(CupertinoIcons.money_dollar_circle_fill, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          const Text(
            '金币',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            '$gold',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(
    BuildContext context,
    ShopItem item,
    int gold,
    AppProvider app,
  ) {
    final canAfford = gold >= item.cost;
    final owned = app.hasItem(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: owned ? AppColors.success.withAlpha(40) : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accent, Color(0xFF64D2FF)],
              ),
            ),
            child: const Icon(
              CupertinoIcons.gift_fill,
              color: CupertinoColors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.desc,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(CupertinoIcons.money_dollar, size: 13, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      '${item.cost} ${item.currency}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      onPressed: owned
                          ? null
                          : canAfford
                              ? () {
                                  app.currencies['gold'] = gold - item.cost;
                                  app.addItem(item.id);
                                }
                              : null,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      minSize: 0,
                      borderRadius: BorderRadius.circular(10),
                      color: owned
                          ? AppColors.success.withAlpha(30)
                          : canAfford
                              ? AppColors.accent
                              : AppColors.textTertiary.withAlpha(30),
                      child: Text(
                        owned ? '已拥有' : (canAfford ? '购买' : '金币不足'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: owned
                              ? AppColors.success
                              : canAfford
                                  ? const Color(0xFFFFFFFF)
                                  : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
