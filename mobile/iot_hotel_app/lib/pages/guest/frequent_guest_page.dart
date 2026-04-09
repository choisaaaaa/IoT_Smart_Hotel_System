import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/frequent_guest_service.dart';

class FrequentGuestPage extends ConsumerStatefulWidget {
  const FrequentGuestPage({super.key});

  @override
  ConsumerState<FrequentGuestPage> createState() => _FrequentGuestPageState();
}

class _FrequentGuestPageState extends ConsumerState<FrequentGuestPage> {
  bool _isLoading = true;
  List<dynamic> _guests = [];

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(frequentGuestServiceProvider).getFrequentGuests();
      if (result.success && mounted) {
        setState(() => _guests = result.data ?? []);
      }
    } catch (e) {
      debugPrint('Error loading guests: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddGuestDialog({Map<String, dynamic>? existingGuest, int? index}) async {
    final nameController = TextEditingController(text: existingGuest?['name']?.toString() ?? '');
    final phoneController = TextEditingController(text: existingGuest?['phone']?.toString() ?? '');
    final idNumberController = TextEditingController(text: existingGuest?['id_number']?.toString() ?? '');
    String roomTypePreference = existingGuest?['room_type_preference']?.toString() ?? 'standard';
    String floorPreference = existingGuest?['floor_preference']?.toString() ?? 'any';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existingGuest != null ? '编辑住客信息' : '添加常旅客'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '姓名',
                      hintText: '请输入住客姓名',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '手机号',
                      hintText: '请输入手机号',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: idNumberController,
                    decoration: InputDecoration(
                      labelText: '证件号码',
                      hintText: '请输入身份证号',
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('偏好设置',
                        style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: roomTypePreference,
                    decoration: InputDecoration(
                      labelText: '房型偏好',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'standard', child: Text('标准间')),
                      DropdownMenuItem(value: 'deluxe', child: Text('豪华间')),
                      DropdownMenuItem(value: 'suite', child: Text('套房')),
                      DropdownMenuItem(value: 'family', child: Text('家庭房')),
                    ],
                    onChanged: (v) => setDialogState(() => roomTypePreference = v ?? 'standard'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: floorPreference,
                    decoration: InputDecoration(
                      labelText: '楼层偏好',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'any', child: Text('无偏好')),
                      DropdownMenuItem(value: 'low', child: Text('低楼层(1-5层)')),
                      DropdownMenuItem(value: 'mid', child: Text('中楼层(6-10层)')),
                      DropdownMenuItem(value: 'high', child: Text('高楼层(11层以上)')),
                    ],
                    onChanged: (v) => setDialogState(() => floorPreference = v ?? 'any'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('请输入姓名')),
                  );
                  return;
                }
                Navigator.pop(ctx, {
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'id_number': idNumberController.text.trim(),
                  'room_type_preference': roomTypePreference,
                  'floor_preference': floorPreference,
                });
              },
              child: Text(existingGuest != null ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      if (existingGuest != null && index != null) {
        final guestId = existingGuest['id'];
        final updateResult = await ref.read(frequentGuestServiceProvider).updateFrequentGuest(guestId, result);
        if (updateResult.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新成功'), backgroundColor: AppColors.success),
          );
          _loadGuests();
        }
      } else {
        final addResult = await ref.read(frequentGuestServiceProvider).addFrequentGuest(result);
        if (addResult.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功'), backgroundColor: AppColors.success),
          );
          _loadGuests();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(addResult.message ?? '添加失败')),
          );
        }
      }
    }
  }

  Future<void> _deleteGuest(int index) async {
    final guest = _guests[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除常旅客'),
        content: Text('确定要删除"${guest['name']}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ref.read(frequentGuestServiceProvider).deleteFrequentGuest(guest['id']);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除'), backgroundColor: AppColors.success),
        );
        _loadGuests();
      }
    }
  }

  String _getRoomTypeLabel(String? type) {
    switch (type) {
      case 'standard':
        return '标准间';
      case 'deluxe':
        return '豪华间';
      case 'suite':
        return '套房';
      case 'family':
        return '家庭房';
      default:
        return '无偏好';
    }
  }

  String _getFloorLabel(String? type) {
    switch (type) {
      case 'low':
        return '低楼层';
      case 'mid':
        return '中楼层';
      case 'high':
        return '高楼层';
      default:
        return '无偏好';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('常旅客管理',
            style: GoogleFonts.notoSansSc(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _showAddGuestDialog(),
            icon: const Icon(Icons.person_add_outlined, color: AppColors.primary),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadGuests,
              child: _guests.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Column(
                            children: [
                              const Icon(Icons.people_outline,
                                  size: 64, color: AppColors.textHint),
                              const SizedBox(height: 16),
                              Text('暂无常旅客',
                                  style: GoogleFonts.notoSansSc(
                                      fontSize: 16, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              Text('添加常旅客，预订时快速填充信息',
                                  style: GoogleFonts.notoSansSc(
                                      fontSize: 13, color: AppColors.textHint)),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: () => _showAddGuestDialog(),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('添加常旅客'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _guests.length,
                      itemBuilder: (context, index) => _buildGuestCard(_guests[index], index),
                    ),
            ),
    );
  }

  Widget _buildGuestCard(Map<String, dynamic> guest, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    (guest['name']?.toString() ?? '?')[0],
                    style: GoogleFonts.notoSansSc(
                        fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(guest['name']?.toString() ?? '未知',
                          style: GoogleFonts.notoSansSc(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(guest['phone']?.toString() ?? '-',
                              style: GoogleFonts.notoSansSc(
                                  fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAddGuestDialog(existingGuest: guest, index: index);
                    } else if (value == 'delete') {
                      _deleteGuest(index);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('删除', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (guest['id_number'] != null || guest['room_type_preference'] != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (guest['id_number'] != null && guest['id_number'].toString().isNotEmpty)
                    _buildInfoChip(
                      Icons.badge_outlined,
                      _maskIdNumber(guest['id_number'].toString()),
                    ),
                  if (guest['room_type_preference'] != null &&
                      guest['room_type_preference'].toString() != 'any')
                    _buildInfoChip(
                      Icons.bed_outlined,
                      '偏好${_getRoomTypeLabel(guest['room_type_preference']?.toString())}',
                    ),
                  if (guest['floor_preference'] != null &&
                      guest['floor_preference'].toString() != 'any')
                    _buildInfoChip(
                      Icons.layers_outlined,
                      '偏好${_getFloorLabel(guest['floor_preference']?.toString())}',
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textHint),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  String _maskIdNumber(String idNumber) {
    if (idNumber.length <= 10) return idNumber;
    return '${idNumber.substring(0, 6)}****${idNumber.substring(idNumber.length - 4)}';
  }
}
