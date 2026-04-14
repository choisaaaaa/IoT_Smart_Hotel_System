import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class SystemSettingsPage extends ConsumerStatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  ConsumerState<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends ConsumerState<SystemSettingsPage> {
  bool _isLoading = false;
  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    // 模拟从本地存储或API加载设置
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _settings = {
        'app_name': 'IoT智慧酒店',
        'app_version': '1.0.0',
        'api_base_url': 'http://8.134.166.69:9000',
        'mqtt_broker': 'mqtt://8.134.166.69:1883',
        'auto_update': true,
        'push_notifications': true,
        'dark_mode': false,
        'language': 'zh-CN',
        'cache_enabled': true,
        'debug_mode': false,
      };
    });
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    // 模拟保存设置
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  void _updateSetting(String key, dynamic value) {
    setState(() {
      _settings[key] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('系统配置', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSectionTitle('应用信息'),
                _buildInfoCard(),
                _buildSectionTitle('服务器配置'),
                _buildServerCard(),
                _buildSectionTitle('功能设置'),
                _buildFeatureCard(),
                _buildSectionTitle('高级设置'),
                _buildAdvancedCard(),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('保存设置'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.notoSansSc(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.app_shortcut),
            title: const Text('应用名称'),
            subtitle: Text(_settings['app_name'] ?? ''),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本号'),
            subtitle: Text(_settings['app_version'] ?? ''),
            trailing: TextButton(
              onPressed: () {
                // 检查更新
              },
              child: const Text('检查更新'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('API服务器地址'),
            subtitle: TextField(
              controller: TextEditingController(text: _settings['api_base_url'] ?? ''),
              decoration: const InputDecoration(
                hintText: '请输入API服务器地址',
                border: InputBorder.none,
              ),
              onChanged: (value) => _updateSetting('api_base_url', value),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.router),
            title: const Text('MQTT服务器地址'),
            subtitle: TextField(
              controller: TextEditingController(text: _settings['mqtt_broker'] ?? ''),
              decoration: const InputDecoration(
                hintText: '请输入MQTT服务器地址',
                border: InputBorder.none,
              ),
              onChanged: (value) => _updateSetting('mqtt_broker', value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('推送通知'),
            subtitle: const Text('接收订单、消息等推送通知'),
            value: _settings['push_notifications'] ?? true,
            onChanged: (value) => _updateSetting('push_notifications', value),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.update),
            title: const Text('自动更新'),
            subtitle: const Text('自动检查并下载新版本'),
            value: _settings['auto_update'] ?? true,
            onChanged: (value) => _updateSetting('auto_update', value),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('深色模式'),
            subtitle: const Text('启用深色主题'),
            value: _settings['dark_mode'] ?? false,
            onChanged: (value) => _updateSetting('dark_mode', value),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言'),
            trailing: DropdownButton<String>(
              value: _settings['language'] ?? 'zh-CN',
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'zh-CN', child: Text('简体中文')),
                DropdownMenuItem(value: 'zh-TW', child: Text('繁體中文')),
                DropdownMenuItem(value: 'en-US', child: Text('English')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _updateSetting('language', value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.storage),
            title: const Text('启用缓存'),
            subtitle: const Text('缓存数据以提高性能'),
            value: _settings['cache_enabled'] ?? true,
            onChanged: (value) => _updateSetting('cache_enabled', value),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.bug_report),
            title: const Text('调试模式'),
            subtitle: const Text('显示调试信息和日志'),
            value: _settings['debug_mode'] ?? false,
            onChanged: (value) => _updateSetting('debug_mode', value),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('清除缓存', style: TextStyle(color: Colors.red)),
            subtitle: const Text('清除所有本地缓存数据'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认清除'),
                  content: const Text('确定要清除所有缓存数据吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('清除'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                // 清除缓存逻辑
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('缓存已清除')),
                  );
                }
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.orange),
            title: const Text('恢复默认设置', style: TextStyle(color: Colors.orange)),
            subtitle: const Text('将所有设置恢复为默认值'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认恢复'),
                  content: const Text('确定要恢复所有默认设置吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('恢复'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                _loadSettings();
              }
            },
          ),
        ],
      ),
    );
  }
}
