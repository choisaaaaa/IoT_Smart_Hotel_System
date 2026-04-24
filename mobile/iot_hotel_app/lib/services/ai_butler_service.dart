import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class AiButlerService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<Map<String, dynamic>>> sendMessage(String message, {int? roomId, String? context}) async {
    debugPrint('AI管家发送消息 - roomId: $roomId, context: $context, message: $message');
    try {
      final data = <String, dynamic>{
        'room_id': roomId ?? 0,
        'text': message,
        'session_id': '${roomId ?? 'app'}_${DateTime.now().millisecondsSinceEpoch}',
      };
      if (context != null) data['context'] = context;

      debugPrint('AI管家请求数据: $data');
      final response = await _dioClient.post(
        '${ApiConstants.aiButler}/chat',
        data: data,
      );
      debugPrint('AI管家响应 - status: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final rawData = response.data['data'] as Map<String, dynamic>;
        final normalized = _normalizeBackendResponse(rawData);
        return ApiResult.success(normalized);
      }
      return ApiResult.failure(response.data['message'] ?? 'AI服务暂不可用');
    } catch (e) {
      debugPrint('AI管家请求失败: $e');
      return _handleLocalFallback(message);
    }
  }

  Map<String, dynamic> _normalizeBackendResponse(Map<String, dynamic> raw) {
    final text = raw['text'] ?? raw['response'] ?? '';
    final action = raw['action'] ?? 'reply';
    final target = raw['target'];
    final audioUrl = raw['audioUrl'];
    final ticketData = raw['ticketData'];
    final frontDeskCount = raw['frontDeskCount'];
    final callId = raw['callId'];

    List<Map<String, String>>? quickActions;
    if (action == 'transfer' && target == 'front_desk') {
      quickActions = [
        {'label': '转接前台', 'action': 'transfer'},
      ];
    } else if (ticketData != null) {
      quickActions = [
        {'label': '查看工单', 'action': 'view_ticket'},
      ];
    }

    return {
      'reply': text,
      'action': action,
      if (target != null) 'target': target,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (ticketData != null) 'ticketData': ticketData,
      if (frontDeskCount != null) 'frontDeskCount': frontDeskCount,
      if (callId != null) 'callId': callId,
      if (quickActions != null) 'quick_actions': quickActions,
    };
  }

  Future<ApiResult<Map<String, dynamic>>> getSmartSuggestions({String? roomNumber}) async {
    return ApiResult.success({
      'suggestions': [
        {'icon': '💡', 'text': '调节灯光亮度', 'action': 'device_control'},
        {'icon': '🌡️', 'text': '调整空调温度', 'action': 'device_control'},
        {'icon': '🪟', 'text': '控制窗帘', 'action': 'curtain'},
        {'icon': '🛎️', 'text': '呼叫前台服务', 'action': 'call_front_desk'},
        {'icon': '🍽️', 'text': '客房送餐服务', 'action': 'room_service'},
        {'icon': '🧹', 'text': '预约清洁服务', 'action': 'housekeeping'},
        {'icon': '📶', 'text': '获取WiFi密码', 'action': 'wifi'},
        {'icon': '🔑', 'text': '自助退房', 'action': 'checkout'},
      ],
    });
  }

  Future<ApiResult<Map<String, dynamic>>> transferToFrontDesk({String? message}) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.aiButler}/chat',
        data: {
          'room_id': 0,
          'text': message ?? '请转接前台',
          'session_id': 'app_${DateTime.now().millisecondsSinceEpoch}',
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final rawData = response.data['data'] as Map<String, dynamic>;
        final normalized = _normalizeBackendResponse(rawData);
        return ApiResult.success(normalized);
      }
      return ApiResult.failure(response.data['message'] ?? '转接失败');
    } catch (e) {
      return ApiResult.failure('转接前台服务暂不可用');
    }
  }

  ApiResult<Map<String, dynamic>> _handleLocalFallback(String message) {
    final lowerMsg = message.toLowerCase();
    String reply;
    List<Map<String, String>>? quickActions;

    if (lowerMsg.contains('灯光') || lowerMsg.contains('灯') || lowerMsg.contains('light')) {
      reply = '好的，我可以帮您控制灯光。您想要：\n1. 打开/关闭灯光\n2. 调节灯光亮度\n3. 切换灯光模式（阅读/休息/氛围）\n\n请告诉我您的需求。';
      quickActions = [
        {'label': '打开灯光', 'action': 'light_on'},
        {'label': '关闭灯光', 'action': 'light_off'},
        {'label': '阅读模式', 'action': 'light_reading'},
      ];
    } else if (lowerMsg.contains('空调') || lowerMsg.contains('温度') || lowerMsg.contains('冷') || lowerMsg.contains('热') || lowerMsg.contains('aircon')) {
      reply = '好的，我可以帮您调节空调。您想要：\n1. 设置温度\n2. 切换模式（制冷/制热/送风）\n3. 调节风速\n\n请告诉我您的需求。';
      quickActions = [
        {'label': '调到26°C', 'action': 'ac_26'},
        {'label': '制冷模式', 'action': 'ac_cool'},
        {'label': '低风速', 'action': 'ac_low'},
      ];
    } else if (lowerMsg.contains('送餐') || lowerMsg.contains('吃') || lowerMsg.contains('餐') || lowerMsg.contains('food') || lowerMsg.contains('room service')) {
      reply = '好的，为您打开客房送餐服务。我们提供：\n1. 中式套餐\n2. 西式简餐\n3. 水果拼盘\n4. 饮品小食\n\n您可以直接在"客房服务"中下单。';
      quickActions = [
        {'label': '查看菜单', 'action': 'room_service'},
        {'label': '推荐套餐', 'action': 'recommend'},
      ];
    } else if (lowerMsg.contains('前台') || lowerMsg.contains('电话') || lowerMsg.contains('联系') || lowerMsg.contains('front desk')) {
      reply = '好的，正在为您转接前台服务。您也可以直接拨打前台电话。';
      quickActions = [
        {'label': '转接前台', 'action': 'transfer'},
        {'label': '拨打前台', 'action': 'call'},
      ];
    } else if (lowerMsg.contains('窗帘') || lowerMsg.contains('curtain')) {
      reply = '好的，我可以帮您控制窗帘。您想要：\n1. 打开窗帘\n2. 关闭窗帘\n3. 半开窗帘\n\n请告诉我您的需求。';
      quickActions = [
        {'label': '打开窗帘', 'action': 'curtain_open'},
        {'label': '关闭窗帘', 'action': 'curtain_close'},
        {'label': '半开窗帘', 'action': 'curtain_half'},
      ];
    } else if (lowerMsg.contains('wifi') || lowerMsg.contains('无线') || lowerMsg.contains('网络密码') || lowerMsg.contains('wifi密码')) {
      reply = '以下是酒店WiFi信息：\n\n📶 网络名称：SmartHotel-Guest\n🔑 密码：hotel2024\n\n如需帮助，请联系前台。';
      quickActions = [
        {'label': '联系前台', 'action': 'front_desk'},
      ];
    } else if (lowerMsg.contains('退房') || lowerMsg.contains('checkout') || lowerMsg.contains('离开')) {
      reply = '好的，我可以帮您办理自助退房。退房前请确认：\n1. 已整理好个人物品\n2. 已归还房卡（如有）\n3. 已结清所有费用\n\n是否现在办理退房？';
      quickActions = [
        {'label': '自助退房', 'action': 'checkout'},
        {'label': '续住一晚', 'action': 'extend'},
      ];
    } else if (lowerMsg.contains('你好') || lowerMsg.contains('hello') || lowerMsg.contains('hi')) {
      reply = '您好！我是您的AI智能管家，很高兴为您服务！🎉\n\n我可以帮您：\n• 控制房间设备（灯光、空调、窗帘等）\n• 预订客房服务（送餐、保洁、维修）\n• 联系前台\n• 办理退房/续住\n\n请问有什么可以帮您的？';
    } else {
      reply = '我理解您的需求。让我为您查找相关信息...\n\n您也可以尝试以下操作：';
      quickActions = [
        {'label': '控制设备', 'action': 'device'},
        {'label': '客房服务', 'action': 'service'},
        {'label': '联系前台', 'action': 'front_desk'},
      ];
    }

    return ApiResult.success({
      'reply': reply,
      if (quickActions != null) 'quick_actions': quickActions,
    });
  }

  Future<ApiResult<void>> broadcast({required int roomId, required String message}) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.aiButler}/broadcast',
        data: {
          'room_id': roomId,
          'message': message,
        },
      );
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '广播发送失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}

final aiButlerServiceProvider = Provider<AiButlerService>((ref) => AiButlerService());
