import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // onboarding 상태 초기화
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('onboarding_completed');
  print('Onboarding status reset. App will show onboarding screens on next launch.');
}