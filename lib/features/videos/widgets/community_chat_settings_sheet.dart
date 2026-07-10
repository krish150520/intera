import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/community_chat_service.dart';

class CommunityChatSettingsSheet extends StatefulWidget {
  final String communityId;
  final CommunityChatMode currentMode;

  const CommunityChatSettingsSheet({
    super.key,
    required this.communityId,
    required this.currentMode,
  });

  @override
  State<CommunityChatSettingsSheet> createState() =>
      _CommunityChatSettingsSheetState();
}

class _CommunityChatSettingsSheetState
    extends State<CommunityChatSettingsSheet> {
  late CommunityChatMode _selectedMode;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.currentMode;
  }

  Future<void> _updateMode(CommunityChatMode mode) async {
    setState(() {
      _selectedMode = mode;
      _isUpdating = true;
    });

    try {
      final success = await CommunityChatService.updateChatMode(
        communityId: widget.communityId,
        newMode: mode,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chat mode updated to: ${mode.label}'),
              backgroundColor: context.appColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context, mode);
        }
      } else {
        throw Exception('Failed to update chat mode settings.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: context.appColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: c.surface.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: c.border.withOpacity(0.3), width: 1),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Chatroom Permissions',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Control who can send text and media messages in this community\'s group chatroom.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isUpdating)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(
                          color: c.primary,
                        ),
                      ),
                    )
                  else
                    ...CommunityChatMode.values.map((mode) {
                      final isSelected = _selectedMode == mode;
                      IconData icon;
                      Color iconColor;

                      switch (mode) {
                        case CommunityChatMode.everyone:
                          icon = Icons.public_rounded;
                          iconColor = Colors.greenAccent;
                          break;
                        case CommunityChatMode.membersOnly:
                          icon = Icons.people_alt_rounded;
                          iconColor = c.primary;
                          break;
                        case CommunityChatMode.announcement:
                          icon = Icons.campaign_rounded;
                          iconColor = Colors.orangeAccent;
                          break;
                      }

                      return InkWell(
                        onTap: () => _updateMode(mode),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? c.primary.withOpacity(0.08)
                                : c.field.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? c.primary.withOpacity(0.4)
                                  : c.border.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: iconColor, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mode.label,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      mode.description,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: c.textMuted,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Radio<CommunityChatMode>(
                                value: mode,
                                groupValue: _selectedMode,
                                activeColor: c.primary,
                                onChanged: (val) {
                                  if (val != null) _updateMode(val);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
