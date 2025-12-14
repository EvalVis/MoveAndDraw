import 'dart:async';
import 'guest_service.dart';
import 'user_service.dart';

class InkService {
  final _guestService = GuestService();
  final _userService = UserService();
  Timer? _refreshTimer;

  Future<int> fetchInk(bool isGuest) async {
    if (isGuest) {
      return await _guestService.refreshInk();
    }
    return await _userService.fetchInk() ?? 0;
  }

  void startRefreshTimer(void Function(int ink) onRefresh, bool isGuest) {
    _refreshTimer = Timer.periodic(const Duration(hours: 1), (_) async {
      final ink = await fetchInk(isGuest);
      onRefresh(ink);
    });
  }

  void dispose() {
    _refreshTimer?.cancel();
  }
}
