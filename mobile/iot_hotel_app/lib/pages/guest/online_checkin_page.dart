import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class OnlineCheckInPage extends StatefulWidget {
  const OnlineCheckInPage({super.key});

  @override
  State<OnlineCheckInPage> createState() => _OnlineCheckInPageState();
}

class _OnlineCheckInPageState extends State<OnlineCheckInPage> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('在线办理入住', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primary),
        ),
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 3) setState(() => _currentStep++);
          },
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep--);
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Row(
                children: [
                  if (_currentStep > 0 && _currentStep < 3)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: details.onStepCancel,
                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('上一步'),
                      ),
                    ),
                  if (_currentStep > 0 && _currentStep < 3) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _currentStep == 3 ? () => Navigator.pop(context) : details.onStepContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(_currentStep == 3 ? '返回首页' : '下一步', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: Text('验证身份', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                child: Column(
                  children: [
                    TextField(decoration: const InputDecoration(labelText: '预订编号 / 手机号', prefixIcon: Icon(Icons.confirmation_number_outlined))),
                    const SizedBox(height: 16),
                    TextField(obscureText: true, decoration: const InputDecoration(labelText: '身份证后四位', prefixIcon: Icon(Icons.badge_outlined))),
                  ],
                ),
              ),
            ),
            Step(
              title: Text('填写信息', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                child: Column(
                  children: [
                    TextField(decoration: const InputDecoration(labelText: '真实姓名', prefixIcon: Icon(Icons.person_outline))),
                    const SizedBox(height: 16),
                    TextField(decoration: const InputDecoration(labelText: '手机号码', prefixIcon: Icon(Icons.phone_outlined))),
                    const SizedBox(height: 16),
                    TextField(decoration: const InputDecoration(labelText: '车牌号（选填）', prefixIcon: Icon(Icons.directions_car_outlined))),
                  ],
                ),
              ),
            ),
            Step(
              title: Text('确认信息', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(label: '预订房间', value: '101号房 标准间'),
                    _InfoRow(label: '入住日期', value: '2026-04-08 14:00'),
                    _InfoRow(label: '离店日期', value: '2026-04-10 12:00'),
                    _InfoRow(label: '住客姓名', value: '张三'),
                    _InfoRow(label: '联系电话', value: '138****8888'),
                    const Divider(height: 32),
                    _InfoRow(label: '房费合计', value: '¥776', isHighlight: true),
                  ],
                ),
              ),
            ),
            Step(
              title: Text('办理成功', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
              isActive: _currentStep >= 3,
              state: _currentStep >= 3 ? StepState.complete : StepState.indexed,
              content: Container(
                padding: const EdgeInsets.all(32),
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.success.withValues(alpha: 0.2))),
                child: Column(
                  children: [
                    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.success)),
                    const SizedBox(height: 24),
                    Text('入住办理成功！', style: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('您的房间已准备就绪，可使用电子门卡进入房间', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(height: 32),
                    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.vibration_rounded), label: const Text('查看电子门卡'), style: FilledButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool isHighlight;
  const _InfoRow({required this.label, required this.value, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: GoogleFonts.notoSansSc(fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500, fontSize: isHighlight ? 18 : 14, color: isHighlight ? AppColors.primary : AppColors.textPrimary)),
        ],
      ),
    );
  }
}
