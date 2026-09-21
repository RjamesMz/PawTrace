import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../services/alert_service.dart';
import 'notifications_sheet.dart';

/// Reusable notification bell with dynamic unread badge count from Supabase alerts.
class NotificationBellButton extends StatefulWidget {
  final Color? color;
  final double size;

  const NotificationBellButton({
    super.key,
    this.color,
    this.size = 24.0,
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  @override
  void initState() {
    super.initState();
    AlertService.instance.refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.color ?? AppColors.onSurfaceVariant;

    return ValueListenableBuilder<int>(
      valueListenable: AlertService.instance.unreadCount,
      builder: (context, count, _) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                count > 0
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_outlined,
                color: iconColor,
                size: widget.size,
              ),
              tooltip: 'Notifications',
              onPressed: () async {
                await NotificationsSheet.show(context);
                AlertService.instance.refreshUnreadCount();
              },
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
