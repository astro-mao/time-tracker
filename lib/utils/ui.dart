import 'package:flutter/material.dart';

/// 全局配色与常用装饰。所有页面统一从这里取色，避免各写各的导致风格不一致。
class AppColors {
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const deep = Color(0xFF1E3A8A);
  static const bg = Color(0xFFF4F6FB);
  static const text = Color(0xFF111827);
  static const sub = Color(0xFF6B7280);
  static const faint = Color(0xFF9CA3AF);
  static const line = Color(0xFFE8ECF4);
  static const success = Color(0xFF10B981);
  static const warn = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
}

/// '#2563EB' -> Color
Color hexColor(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

/// 白色圆角卡片 + 柔和投影
BoxDecoration softCard({double radius = 18, Color? color}) => BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(.05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );

/// 蓝色渐变卡片（用于"今日概览""累计"这类重点信息）
BoxDecoration gradientCard({double radius = 20}) => BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4F83F1), AppColors.primary, AppColors.primaryDark],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(.25),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    );

/// 小圆角标签（事件筛选、状态标记）
Widget pill(
  String label, {
  bool active = false,
  Color? dotColor,
  VoidCallback? onTap,
}) {
  final bg = active ? AppColors.primary : Colors.white;
  final fg = active ? Colors.white : AppColors.sub;
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.line,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? Colors.white : dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 区块标题：左边一条竖线 + 标题 + 可选右侧说明或操作按钮
Widget sectionTitle(
  String title, {
  String? trailing,
  Widget? action,
  EdgeInsets? padding,
}) {
  return Padding(
    padding: padding ?? const EdgeInsets.fromLTRB(4, 4, 4, 10),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const Spacer(),
        if (action != null)
          action
        else if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(fontSize: 12, color: AppColors.faint),
          ),
      ],
    ),
  );
}
