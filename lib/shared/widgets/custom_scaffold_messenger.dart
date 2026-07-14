import 'package:flutter/material.dart';

class CustomScaffoldMessenger extends ScaffoldMessenger {
  const CustomScaffoldMessenger({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => _CustomScaffoldMessengerState();
}

class _CustomScaffoldMessengerState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackbar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    // 1. Extract the raw text from the original SnackBar content
    String message = '';
    if (snackbar.content is Text) {
      message = (snackbar.content as Text).data ?? '';
    } else {
      // Fallback
      message = snackbar.content.toString();
    }

    // 2. Build the premium redesigned SnackBar
    final customSnackBar = _buildPremiumSnackBar(message, snackbar);

    // 3. Delegate to original ScaffoldMessengerState
    return super.showSnackBar(
      customSnackBar,
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
  }

  SnackBar _buildPremiumSnackBar(String message, SnackBar original) {
    String title = "Notification";
    String subtitle = message.trim();
    Widget iconWidget;
    Color categoryColor = const Color(0xFF9B59F5); // Default Purple for Info

    // If message contains a newline, split it into custom Title and Subtitle
    if (subtitle.contains('\n')) {
      final parts = subtitle.split('\n');
      title = parts[0].trim();
      subtitle = parts.sublist(1).join('\n').trim();
    }

    // Try to extract a leading emoji to render inside the icon container
    final emojiRegExp = RegExp(
      r'^([\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F000}-\u{1F0FF}\u{1F100}-\u{1F1FF}\u{1F200}-\u{1F2FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F900}-\u{1F9FF}❓📊⚠️🎉✅👍❌🛑🚨])\s*',
      unicode: true,
    );
    final match = emojiRegExp.firstMatch(subtitle);
    String? extractedEmoji;
    if (match != null) {
      extractedEmoji = match.group(1);
      subtitle = subtitle.substring(match.end).trim();
    }

    // Automatic classification based on message contents
    final lowerMessage = message.toLowerCase();
    IconData defaultIcon = Icons.info_outline_rounded;

    if (lowerMessage.contains('success') ||
        lowerMessage.contains('publish') ||
        lowerMessage.contains('creat') ||
        lowerMessage.contains('updat') ||
        lowerMessage.contains('save') ||
        lowerMessage.contains('sync') ||
        lowerMessage.contains('sent') ||
        lowerMessage.contains('remov') ||
        lowerMessage.contains('delet') ||
        lowerMessage.contains('claim') ||
        message.contains('🎉') ||
        message.contains('✅') ||
        message.contains('👍')) {
      title = title == "Notification" ? "Success" : title;
      categoryColor = const Color(0xFF4CAF50); // Green
      defaultIcon = Icons.check_circle_rounded;
    } else if (lowerMessage.contains('fail') ||
        lowerMessage.contains('error') ||
        lowerMessage.contains('exception') ||
        lowerMessage.contains('could not') ||
        lowerMessage.contains('denied')) {
      title = title == "Notification" ? "Error" : title;
      categoryColor = const Color(0xFFF44336); // Red
      defaultIcon = Icons.error_outline_rounded;
    } else if (lowerMessage.contains('warning') ||
        lowerMessage.contains('warn') ||
        lowerMessage.contains('caution') ||
        lowerMessage.contains('restrict') ||
        lowerMessage.contains('flagged') ||
        message.contains('⚠️')) {
      title = title == "Notification" ? "Warning" : title;
      categoryColor = const Color(0xFFFF9800); // Orange
      defaultIcon = Icons.warning_rounded;
    } else {
      title = title == "Notification" ? "Info" : title;
      categoryColor = const Color(0xFF9B59F5); // Purple (Intera Brand Purple)
      defaultIcon = Icons.info_outline_rounded;
    }

    // Determine icon layout
    if (extractedEmoji != null) {
      iconWidget = Text(
        extractedEmoji,
        style: const TextStyle(fontSize: 18),
      );
    } else {
      iconWidget = Icon(
        defaultIcon,
        color: categoryColor,
        size: 20,
      );
    }

    final customContent = Builder(
      builder: (context) {
        return Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF454545), Color(0xFF2E2E2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Render action inline if the original SnackBar had an action
              if (original.action != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: original.action!.onPressed,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    original.action!.label,
                    style: TextStyle(
                      color: original.action!.textColor ?? categoryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: categoryColor.withOpacity(0.3),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: iconWidget,
                ),
              ),
            ],
          ),
        );
      },
    );

    return SnackBar(
      content: customContent,
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      duration: original.duration,
      animation: original.animation,
      onVisible: original.onVisible,
      dismissDirection: original.dismissDirection,
    );
  }
}
