import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

enum ConnectivityStatus { online, offline }

class ConnectivityService extends ChangeNotifier {
  ConnectivityStatus _status = ConnectivityStatus.online;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;

  ConnectivityStatus get status => _status;
  bool get isOffline => _status == ConnectivityStatus.offline;
  bool get isOnline => _status == ConnectivityStatus.online;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // If any result is not none, we consider it online
    final hasConnection = results.any((result) => result != ConnectivityResult.none);
    
    final newStatus = hasConnection ? ConnectivityStatus.online : ConnectivityStatus.offline;

    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
      debugPrint('Connectivity Changed: $_status');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
