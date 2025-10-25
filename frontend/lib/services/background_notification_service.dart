import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter_app_badger/flutter_app_badger.dart';  // 임시 비활성화
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/litten.dart';

class BackgroundNotificationService {
  static final BackgroundNotificationService _instance = BackgroundNotificationService._internal();
  factory BackgroundNotificationService() => _instance;
  BackgroundNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _notificationId = 0;
  int _badgeCount = 0;

  // 초기화
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('🎯 BackgroundNotificationService 이미 초기화됨');
      return;
    }

    int retryCount = 0;
    const maxRetries = 3;

    while (!_initialized && retryCount < maxRetries) {
      try {
        debugPrint('🔔 BackgroundNotificationService 초기화 시도 ${retryCount + 1}/$maxRetries');

      // Android 초기화 설정
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS 초기화 설정
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // 로컬 노티피케이션 초기화
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // 권한 요청
      await _requestPermissions();

      // WorkManager 초기화
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      // 배지 초기화
      await _initializeBadge();

        _initialized = true;
        debugPrint('✅ BackgroundNotificationService 초기화 성공');
        return;
      } catch (e) {
        retryCount++;
        debugPrint('❌ BackgroundNotificationService 초기화 실패 (시도 $retryCount/$maxRetries): $e');
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
    }

    if (!_initialized) {
      debugPrint('🔴 BackgroundNotificationService 초기화 최종 실패');
    }
  }

  // 권한 요청
  Future<void> _requestPermissions() async {
    try {
      // Android 권한 요청
      if (defaultTargetPlatform == TargetPlatform.android) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          await androidImplementation.requestNotificationsPermission();
          await androidImplementation.requestExactAlarmsPermission();
        }
      }

      // iOS 권한 요청 - iOS 14+ 지원을 위한 조건부 처리
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              );
        } catch (e) {
          debugPrint('⚠️ iOS 권한 요청 중 오류 (무시 가능): $e');
        }
      }

      debugPrint('✅ 알림 권한 요청 완료');
    } catch (e) {
      debugPrint('❌ 알림 권한 요청 실패: $e');
    }
  }

  // 배지 초기화
  Future<void> _initializeBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _badgeCount = prefs.getInt('badge_count') ?? 0;
      await _updateBadge();
      debugPrint('✅ 앱 배지 초기화: $_badgeCount');
    } catch (e) {
      debugPrint('❌ 배지 초기화 실패: $e');
    }
  }

  // 배지 업데이트 (임시 비활성화)
  Future<void> _updateBadge() async {
    try {
      // if (_badgeCount > 0) {
      //   await FlutterAppBadger.updateBadgeCount(_badgeCount);
      // } else {
      //   await FlutterAppBadger.removeBadge();
      // }

      // 로컬 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('badge_count', _badgeCount);

      debugPrint('🔰 앱 배지 업데이트: $_badgeCount (임시 비활성화)');
    } catch (e) {
      debugPrint('❌ 배지 업데이트 실패: $e');
    }
  }

  // 알림 표시 (안전 버전)
  Future<void> showNotification({
    required String title,
    required String body,
    required String littenId,
    String? payload,
  }) async {
    // 초기화 확인
    if (!_initialized) {
      debugPrint('⚠️ 알림 서비스 미초기화 - 초기화 시도');
      await initialize();
      if (!_initialized) {
        debugPrint('❌ 알림 표시 실패 - 서비스 초기화 불가');
        return;
      }
    }

    try {
      _notificationId++;
      _badgeCount++;

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'litten_notifications',
        '리튼 알림',
        channelDescription: '리튼 일정 알림',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        _notificationId,
        title,
        body,
        platformChannelSpecifics,
        payload: payload ?? littenId,
      );

      await _updateBadge();
      debugPrint('🔔 알림 표시: $title - $body');
    } catch (e) {
      debugPrint('❌ 알림 표시 실패: $e');
    }
  }

  // 스케줄된 알림 등록
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String littenId,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'litten_scheduled',
        '리튼 예약 알림',
        channelDescription: '리튼 예약된 일정 알림',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        _convertToTZDateTime(scheduledDate),
        platformChannelSpecifics,
        payload: payload ?? littenId,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint('⏰ 예약 알림 등록: $title - ${DateFormat('yyyy-MM-dd HH:mm').format(scheduledDate)}');
    } catch (e) {
      debugPrint('❌ 예약 알림 등록 실패: $e');
    }
  }

  // DateTime을 TZDateTime으로 변환
  dynamic _convertToTZDateTime(DateTime dateTime) {
    // timezone 패키지를 사용하지 않는 경우 DateTime 그대로 반환
    return dateTime;
  }

  // 백그라운드 작업 등록
  Future<void> registerBackgroundTask() async {
    try {
      await Workmanager().registerPeriodicTask(
        "litten-notification-check",
        "notificationCheck",
        frequency: const Duration(minutes: 15), // 최소 15분
        constraints: Constraints(
          networkType: NetworkType.unmetered,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );

      debugPrint('✅ 백그라운드 작업 등록 완료');
    } catch (e) {
      debugPrint('❌ 백그라운드 작업 등록 실패: $e');
    }
  }

  // 모든 예약된 알림 취소
  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('🗑️ 모든 예약 알림 취소');
    } catch (e) {
      debugPrint('❌ 알림 취소 실패: $e');
    }
  }

  // 특정 알림 취소
  Future<void> cancelNotification(int id) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      debugPrint('🗑️ 알림 취소: $id');
    } catch (e) {
      debugPrint('❌ 알림 취소 실패: $e');
    }
  }

  // 배지 카운트 감소
  Future<void> decreaseBadgeCount() async {
    if (_badgeCount > 0) {
      _badgeCount--;
      await _updateBadge();
    }
  }

  // 배지 초기화
  Future<void> clearBadge() async {
    _badgeCount = 0;
    await _updateBadge();
  }

  // 알림 탭 처리
  void _onNotificationTapped(NotificationResponse notificationResponse) async {
    try {
      final String? payload = notificationResponse.payload;
      debugPrint('📱 알림 탭됨: $payload');

      // 배지 카운트 감소
      await decreaseBadgeCount();

      // TODO: 특정 리튼으로 네비게이션
    } catch (e) {
      debugPrint('❌ 알림 탭 처리 실패: $e');
    }
  }

  // 현재 배지 카운트 반환
  int get badgeCount => _badgeCount;
}

// 백그라운드 콜백 함수
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('🔄 백그라운드 작업 실행: $task');

      switch (task) {
        case "notificationCheck":
          await _checkNotificationsInBackground();
          break;
      }

      return Future.value(true);
    } catch (e) {
      debugPrint('❌ 백그라운드 작업 실패: $e');
      return Future.value(false);
    }
  });
}

// 백그라운드에서 알림 체크
Future<void> _checkNotificationsInBackground() async {
  try {
    debugPrint('🔍 백그라운드 알림 체크 시작');

    // SharedPreferences에서 리튼 데이터 읽기
    final prefs = await SharedPreferences.getInstance();
    final littensJson = prefs.getString('littens');

    if (littensJson == null) {
      debugPrint('📭 저장된 리튼 데이터 없음');
      return;
    }

    final List<dynamic> littensData = jsonDecode(littensJson);
    final littens = littensData.map((data) => Litten.fromJson(data)).toList();

    final now = DateTime.now();
    final currentMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    // 현재 시간에 발생해야 할 알림 찾기
    for (final litten in littens) {
      if (litten.schedule == null) continue;

      final schedule = litten.schedule!;
      for (final rule in schedule.notificationRules) {
        if (!rule.isEnabled) continue;

        // 알림 시간 계산
        final scheduleDateTime = DateTime(
          schedule.date.year,
          schedule.date.month,
          schedule.date.day,
          schedule.startTime.hour,
          schedule.startTime.minute,
        );

        final triggerTime = scheduleDateTime.add(Duration(minutes: rule.timing.minutesOffset));
        final triggerMinute = DateTime(
          triggerTime.year,
          triggerTime.month,
          triggerTime.day,
          triggerTime.hour,
          triggerTime.minute,
        );

        // 현재 시간과 일치하는지 확인
        if (triggerMinute.isAtSameMomentAs(currentMinute)) {
          final message = _createNotificationMessage(litten, schedule, rule);

          await BackgroundNotificationService().showNotification(
            title: '리튼 알림',
            body: message,
            littenId: litten.id,
          );

          debugPrint('🔔 백그라운드 알림 발송: ${litten.title}');
        }
      }
    }

  } catch (e) {
    debugPrint('❌ 백그라운드 알림 체크 실패: $e');
  }
}

// 알림 메시지 생성
String _createNotificationMessage(Litten litten, LittenSchedule schedule, NotificationRule rule) {
  final startHour = schedule.startTime.hour.toString().padLeft(2, '0');
  final startMinute = schedule.startTime.minute.toString().padLeft(2, '0');
  final endHour = schedule.endTime.hour.toString().padLeft(2, '0');
  final endMinute = schedule.endTime.minute.toString().padLeft(2, '0');
  final timeStr = '$startHour:$startMinute - $endHour:$endMinute';

  switch (rule.frequency) {
    case NotificationFrequency.onDay:
      return '오늘 $timeStr에 "${litten.title}" 일정이 있습니다.';
    case NotificationFrequency.oneDayBefore:
      return '내일 $timeStr에 "${litten.title}" 일정이 있습니다.';
    case NotificationFrequency.daily:
      return '매일 $timeStr "${litten.title}" 일정 알림입니다.';
    case NotificationFrequency.weekly:
      return '매주 $timeStr "${litten.title}" 일정 알림입니다.';
    case NotificationFrequency.monthly:
      return '매월 $timeStr "${litten.title}" 일정 알림입니다.';
    case NotificationFrequency.yearly:
      return '매년 $timeStr "${litten.title}" 일정 알림입니다.';
  }
}