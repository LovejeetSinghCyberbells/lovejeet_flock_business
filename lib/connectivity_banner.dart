import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({required this.child, super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isOffline = false;
  late final Connectivity _connectivity;
  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      // results is a List<ConnectivityResult>
      final isOffline =
          results.every((r) => r == ConnectivityResult.none);
      setState(() {
        _isOffline = isOffline;
      });
    });
    _checkInitial();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _checkInitial() async {
    final result = await _connectivity.checkConnectivity();
    setState(() {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.red,
              child: SafeArea(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    'No internet connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
