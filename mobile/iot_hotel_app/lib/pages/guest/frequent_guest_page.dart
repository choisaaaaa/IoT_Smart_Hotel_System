import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../models/frequent_guest.dart';

class FrequentGuestPage extends ConsumerStatefulWidget {
  const FrequentGuestPage({super.key});

  @override
  ConsumerState<FrequentGuestPage> createState() => _FrequentGuestPageState();
}

class _FrequentGuestPageState extends ConsumerState<FrequentGuestPage> {
  List<FrequentGuest> _guests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    setState(() => _isLoading = true);
    try {
      final dio = DioClient();
      final response = await dio.get(ApiConstants.frequentGuests);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        if (data is List) {
          setState(() => _guests = data.map((g) => FrequentGuest.fromJson(g as Map<String, dynamic>)).toList());
        }
      }
    } catch (e) {
      debugPrint('frequentGuests: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGuest(FrequentGuest guest) async {
    try {
      final dio = DioClient();
      if (guest.id != null) {
        await dio.put('${ApiConstants.frequentGuests}/${guest.id}', data: guest.toJson());
      } else {
        await dio.post(ApiConstants.frequentGuests, data: guest.toJson());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功'), backgroundColor: AppColors.success),
        );
        _loadGuests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    }
  }

  Future<void> _deleteGuest(int id) async {
    try {
      final dio = DioClient();
      await dio.delete('${ApiConstants.frequentGuests}/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除'), backgroundColor: AppColors.success),
        );
        _loadGuests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败，请重试')),
        );
      }
    }
  }

  void _showAddEditDialog({FrequentGuest? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final idNumberCtrl = TextEditingController(text: existing?.idNumber ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    String idType = existing?.idType ?? 'idcard';
    String relationship = existing?.relationship ?? 'self';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(existing != null ? '编辑常旅客' : '添加常旅客'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: '姓名',
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: idType,
                      decoration: InputDecoration(
                        labelText: '证件类型',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'idcard', child: Text('身份证/永居证/居住证')),
                        DropdownMenuItem(value: 'hkm_pass', child: Text('港澳居民来往内地通行证')),
                        DropdownMenuItem(value: 'taiwan_pass', child: Text('台湾居民来往大陆通行证')),
                        DropdownMenuItem(value: 'passport', child: Text('外国护照')),
                        DropdownMenuItem(value: 'other', child: Text('其他')),
                      ],
                      onChanged: (v) => setDialogState(() => idType = v ?? 'idcard'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: idNumberCtrl,
                      decoration: InputDecoration(
                        labelText: '证件号码',
                        prefixIcon: const Icon(Icons.numbers_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: '手机号 (可选)',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: relationship,
                      decoration: InputDecoration(
                        labelText: '与您的关系',
                        prefixIcon: const Icon(Icons.people_outline, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'self', child: Text('本人')),
                        DropdownMenuItem(value: 'spouse', child: Text('配偶')),
                        DropdownMenuItem(value: 'child', child: Text('子女')),
                        DropdownMenuItem(value: 'parent', child: Text('父母')),
                        DropdownMenuItem(value: 'friend', child: Text('朋友')),
                        DropdownMenuItem(value: 'colleague', child: Text('同事')),
                        DropdownMenuItem(value: 'other', child: Text('其他')),
                      ],
                      onChanged: (v) => setDialogState(() => relationship = v ?? 'self'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入姓名')));
                      return;
                    }
                    if (idNumberCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入证件号码')));
                      return;
                    }
                    Navigator.pop(ctx);
                    _saveGuest(FrequentGuest(
                      id: existing?.id,
                      name: nameCtrl.text.trim(),
                      idType: idType,
                      idNumber: idNumberCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      relationship: relationship,
                    ));
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(FrequentGuest guest) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除常旅客「${guest.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (guest.id != null) _deleteGuest(guest.id!);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _quickFillToBooking(FrequentGuest guest) {
    Navigator.pop(context, guest.toJson());
  }

  IconData _relationshipIcon(String rel) {
    switch (rel) {
      case 'self': return Icons.person;
      case 'spouse': return Icons.favorite;
      case 'child': return Icons.child_care;
      case 'parent': return Icons.elderly;
      case 'friend': return Icons.people;
      case 'colleague': return Icons.work;
      default: return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('常旅客管理', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _guests.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadGuests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _guests.length,
                    itemBuilder: (ctx, index) => _buildGuestCard(_guests[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: AppColors.textHint.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('暂无常旅客信息', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('添加常旅客后，预订时可快速填充入住人信息', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.person_add),
            label: const Text('添加常旅客'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestCard(FrequentGuest guest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_relationshipIcon(guest.relationship), color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(guest.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(guest.relationshipLabel, style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${guest.idTypeLabel}：${guest.maskedIdNumber}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      if (guest.phone != null && guest.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('手机：${guest.phone}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'edit': _showAddEditDialog(existing: guest); break;
                      case 'fill': _quickFillToBooking(guest); break;
                      case 'delete': _confirmDelete(guest); break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('编辑')])),
                    const PopupMenuItem(value: 'fill', child: Row(children: [Icon(Icons.content_paste_outlined, size: 18), SizedBox(width: 8), Text('快速填充到预订')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppColors.error), SizedBox(width: 8), Text('删除', style: TextStyle(color: AppColors.error))])),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _quickFillToBooking(guest),
                  icon: const Icon(Icons.content_paste_outlined, size: 16),
                  label: const Text('快速填充'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showAddEditDialog(existing: guest),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('编辑'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary, padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
