import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback onNewChat;
  final VoidCallback onHistory;
  final VoidCallback onTemplates;
  final VoidCallback onSettings;
  final VoidCallback onAbout;

  const AppDrawer({
    super.key,
    required this.onNewChat,
    required this.onHistory,
    required this.onTemplates,
    required this.onSettings,
    required this.onAbout,
  });

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback action,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop();
        action();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: cs.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.balance, size: 36, color: cs.onPrimaryContainer),
                  const SizedBox(height: 8),
                  Text(
                    'دستیار',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'کاملاً آفلاین؛ اطلاعات شما از گوشی خارج نمی‌شود',
                    style: TextStyle(color: cs.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _item(context, Icons.add_comment_outlined, 'گفتگوی جدید', onNewChat),
            _item(context, Icons.history, 'تاریخچه', onHistory),
            _item(
              context,
              Icons.description_outlined,
              'تهیه متن حقوقی',
              onTemplates,
            ),
            const Divider(),
            _item(context, Icons.settings_outlined, 'تنظیمات', onSettings),
            _item(context, Icons.info_outline, 'اطلاعات و وضعیت داده‌ها', onAbout),
          ],
        ),
      ),
    );
  }
}
