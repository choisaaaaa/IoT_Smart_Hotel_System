import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class RoomServicePage extends StatelessWidget {
  const RoomServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('客房服务', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildServiceCard(
            context,
            'AI 智能管家',
            '智能对话，快速响应您的需求',
            Icons.smart_toy_rounded,
            AppColors.primary,
            () {},
          ),
          _buildServiceCard(
            context,
            '客房送物',
            '毛巾、水、洗漱用品等物品配送',
            Icons.delivery_dining_rounded,
            AppColors.secondary,
            () {},
          ),
          _buildServiceCard(
            context,
            '联系前台',
            '一键拨打前台电话',
            Icons.support_agent_rounded,
            AppColors.info,
            () {},
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('房间设备控制', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
            children: const [
              _DeviceControlTile(icon: Icons.light_mode_rounded, name: '灯光', status: '开启', isOn: true),
              _DeviceControlTile(icon: Icons.ac_unit_rounded, name: '空调', status: '24°C 制冷', isOn: true),
              _DeviceControlTile(icon: Icons.curtains_rounded, name: '窗帘', status: '关闭', isOn: false),
              _DeviceControlTile(icon: Icons.tv_rounded, name: '电视', status: '关闭', isOn: false),
              _DeviceControlTile(icon: Icons.lock_rounded, name: '门锁', status: '已锁定', isOn: true),
              _DeviceControlTile(icon: Icons.volume_up_rounded, name: '音响', status: '关闭', isOn: false),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, size: 28, color: color)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceControlTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String status;
  final bool isOn;
  const _DeviceControlTile({required this.icon, required this.name, required this.status, required this.isOn});

  @override
  Widget build(BuildContext context) {
    final color = isOn ? AppColors.primary : AppColors.textHint;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isOn ? AppColors.primary.withValues(alpha: 0.2) : Colors.grey.shade100)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(name, style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(status, style: GoogleFonts.notoSansSc(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
