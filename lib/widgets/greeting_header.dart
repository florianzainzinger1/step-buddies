import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_service.dart';
import '../theme/theme_colors.dart';
import '../l10n/app_strings.dart';

class GreetingHeader extends StatelessWidget {
  final String? userName;
  final TextStyle? style;

  const GreetingHeader({
    super.key,
    this.userName,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final period = themeService.currentPeriod;
    final colors = themeService.colors;

    final greeting = _getGreeting(period, userName);
    final emoji = _getEmoji(period);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          greeting,
          style: style ??
              TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
        ),
        const SizedBox(width: 8),
        Text(
          emoji,
          style: const TextStyle(fontSize: 22),
        ),
      ],
    );
  }

  String _getGreeting(TimePeriod period, String? name) {
    final displayName = name ?? '';
    final hasName = displayName.isNotEmpty;

    switch (period) {
      case TimePeriod.dawn:
        return hasName
            ? AppStrings.greetingDawn(displayName)
            : AppStrings.greetingDawnNoName;
      case TimePeriod.day:
        return hasName
            ? AppStrings.greetingDay(displayName)
            : AppStrings.greetingDayNoName;
      case TimePeriod.dusk:
        return hasName
            ? AppStrings.greetingDusk(displayName)
            : AppStrings.greetingDuskNoName;
      case TimePeriod.night:
        return hasName
            ? AppStrings.greetingNight(displayName)
            : AppStrings.greetingNightNoName;
    }
  }

  String _getEmoji(TimePeriod period) {
    switch (period) {
      case TimePeriod.dawn:
        return '\u2600\uFE0F'; // sun
      case TimePeriod.day:
        return '\uD83D\uDC4B'; // waving hand
      case TimePeriod.dusk:
        return '\uD83C\uDF05'; // sunset
      case TimePeriod.night:
        return '\uD83C\uDF19'; // crescent moon
    }
  }
}

// Compact greeting for smaller spaces
class CompactGreeting extends StatelessWidget {
  final String? userName;

  const CompactGreeting({super.key, this.userName});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final period = themeService.currentPeriod;
    final colors = themeService.colors;

    final greeting = _getCompactGreeting(period);
    final emoji = _getEmoji(period);

    return Text(
      '$greeting $emoji',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
    );
  }

  String _getCompactGreeting(TimePeriod period) {
    switch (period) {
      case TimePeriod.dawn:
        return 'Guten Morgen';
      case TimePeriod.day:
        return 'Hallo';
      case TimePeriod.dusk:
        return 'Guten Abend';
      case TimePeriod.night:
        return 'Gute Nacht';
    }
  }

  String _getEmoji(TimePeriod period) {
    switch (period) {
      case TimePeriod.dawn:
        return '\u2600\uFE0F';
      case TimePeriod.day:
        return '\uD83D\uDC4B';
      case TimePeriod.dusk:
        return '\uD83C\uDF05';
      case TimePeriod.night:
        return '\uD83C\uDF19';
    }
  }
}
