import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

/// 디바이스 관리 화면 (1계정 3장치).
///
/// 현재 회원의 등록 디바이스(uuid1/2/3 슬롯)를 조회하고, 다른 기기를 원격 해제한다.
/// "이 기기"는 로컬 device_uuid와 일치하는 슬롯으로 식별하며 원격 해제 대상에서 제외한다.
///
/// NOTE: 사용자 문구는 우선 한국어로 작성. 다국어(ARB 30개 언어) 키 추가는 후속 작업.
class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _devices = [];
  String? _currentUuid;
  String? _token;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    debugPrint('[DeviceManagementScreen] _load 진입');
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _currentUuid = prefs.getString('device_uuid');
    if (_token != null) {
      _devices = await _api.getDevices(token: _token!);
    }
    debugPrint('[DeviceManagementScreen] _load 완료 - 슬롯 ${_devices.length}개, 현재기기: $_currentUuid');
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _removeDevice(String uuid) async {
    debugPrint('[DeviceManagementScreen] _removeDevice - uuid: $uuid');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기기 등록 해제'),
        content: const Text('이 기기의 로그인을 해제합니다.\n해당 기기는 다시 로그인해야 동기화할 수 있습니다.\n계속하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('해제'),
          ),
        ],
      ),
    );
    if (confirmed != true || _token == null) return;

    final ok = await _api.removeDevice(token: _token!, uuid: uuid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '기기를 해제했습니다.' : '기기 해제에 실패했습니다.'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
    if (ok) await _load();
  }

  // uuid 앞 8자리만 노출 (식별용 마스킹)
  String _maskUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) return '';
    return uuid.length <= 8 ? uuid : '${uuid.substring(0, 8)}…';
  }

  @override
  Widget build(BuildContext context) {
    final occupiedCount = _devices.where((d) => d['occupied'] == true).length;
    return Scaffold(
      appBar: AppBar(title: const Text('기기 관리')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.devices, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '하나의 계정은 최대 3대까지 로그인할 수 있습니다.\n현재 $occupiedCount / 3대 사용 중입니다.',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._devices.map(_buildDeviceTile),
                ],
              ),
            ),
    );
  }

  Widget _buildDeviceTile(Map<String, dynamic> device) {
    final slot = device['slot'];
    final uuid = device['uuid'] as String?;
    final occupied = device['occupied'] == true;
    final isCurrent = occupied && uuid == _currentUuid;

    if (!occupied) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.smartphone, color: Colors.grey.shade400),
          title: Text('기기 $slot', style: TextStyle(color: Colors.grey.shade500)),
          subtitle: const Text('비어 있음'),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: Icon(Icons.smartphone, color: isCurrent ? Colors.blue : Colors.grey.shade700),
        title: Row(
          children: [
            Text('기기 $slot'),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('이 기기', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ],
        ),
        subtitle: Text('ID: ${_maskUuid(uuid)}'),
        trailing: isCurrent
            ? null
            : TextButton(
                onPressed: () => _removeDevice(uuid!),
                child: const Text('등록 해제', style: TextStyle(color: Colors.red)),
              ),
      ),
    );
  }
}
