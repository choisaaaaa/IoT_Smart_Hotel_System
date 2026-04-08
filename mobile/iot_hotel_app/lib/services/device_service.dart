import '../core/network/dio_client.dart';
import '../core/network/api_result.dart';
import '../core/constants/api_constants.dart';

class DeviceService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<dynamic>>> getMyRoomDevices() async {
    try {
      // 在实际项目中，通常是根据当前用户的有效预订获取房间号，再获取设备
      // 这里简化为获取所有设备，或者后端有专门的 /my-room/devices 接口
      final response = await _dioClient.get(ApiConstants.devices);
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(List<dynamic>.from(response.data['data']));
      }
      return ApiResult.failure(response.data['message'] ?? '获取设备失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }

  Future<ApiResult<void>> controlDevice(int deviceId, String command, dynamic value) async {
    try {
      final response = await _dioClient.post(
        '${ApiConstants.devices}/control',
        data: {
          'deviceId': deviceId,
          'command': command,
          'value': value,
        },
      );
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.failure(response.data['message'] ?? '操作失败');
    } catch (e) {
      return ApiResult.failure('网络错误：$e');
    }
  }
}
