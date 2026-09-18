import 'package:flutter/material.dart';
import '../main.dart';
import 'users_list_screen.dart';
import 'deposit_methods_screen.dart';
import 'wallet_requests_screen.dart';
import 'disputes_screen.dart';
import 'support_requests_screen.dart';
import 'orders_screen.dart';
import 'admin_listings_screen.dart';
import 'broadcast_screen.dart';
import 'finance_screen.dart';
import 'verification_list_screen.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await ApiService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.hint, size: 20),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: AppColors.bg),
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 36),
                  SizedBox(width: 12),
                  Text('MYGame Admin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            _navItem(context, Icons.dashboard_outlined, 'Overview', () {}),
            _navItem(context, Icons.people_outline, 'Users', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersListScreen()))),
            _navItem(context, Icons.verified_user_outlined, 'Verification', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationListScreen()))),
            _navItem(context, Icons.storefront_outlined, 'Listings', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminListingsScreen()))),
            _navItem(context, Icons.receipt_long_outlined, 'Orders', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()))),
            _navItem(context, Icons.gavel_outlined, 'Disputes', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DisputesScreen()))),
            _navItem(context, Icons.calendar_month_outlined, 'Rentals & Installments', () => _comingSoon(context)),
            _navItem(context, Icons.account_balance_wallet_outlined, 'Wallet', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletRequestsScreen()))),
            _navItem(context, Icons.support_agent_outlined, 'Support', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportRequestsScreen()))),
            _navItem(context, Icons.bar_chart_outlined, 'Reports', () => _comingSoon(context)),
            _navItem(context, Icons.notifications_outlined, 'Notifications', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BroadcastScreen()))),
            _navItem(context, Icons.campaign_outlined, 'Promotions', () => _comingSoon(context)),
            _navItem(context, Icons.attach_money_outlined, 'Finance', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen()))),
            _navItem(context, Icons.settings_outlined, 'Settings', () => _comingSoon(context)),
            const Divider(color: AppColors.border),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Welcome — select a section from the menu', style: TextStyle(color: AppColors.hint)),
      ),
    );
  }
}
