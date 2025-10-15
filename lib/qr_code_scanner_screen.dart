import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flock/services/logger_service.dart';

class QRScanScreen extends StatefulWidget {
  final String venueId;
  final String token;

  const QRScanScreen({super.key, required this.venueId, required this.token});

  @override
  _QRScanScreenState createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  bool _isPermissionGranted = false;
  bool _isScanned = false;
  bool _isLoading = false;
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _couponController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPermission();
    print('QRScanScreen initialized with venue_id: ${widget.venueId}');
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    var status = await Permission.camera.status;
    print("QRScanScreen permission status: $status");
    if (status.isDenied) {
      status = await Permission.camera.request();
    }
    if (status.isGranted) {
      setState(() => _isPermissionGranted = true);
    } else if (status.isPermanentlyDenied) {
      Fluttertoast.showToast(
        msg: 'Camera permission is required. Please enable it in settings.',
      );
      await openAppSettings();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        var newStatus = await Permission.camera.status;
        if (newStatus.isGranted) {
          setState(() => _isPermissionGranted = true);
        }
      });
    } else {
      Navigator.pop(context);
      Fluttertoast.showToast(msg: 'Camera Permission Denied!');
    }
  }

  Future<void> _verifyCouponCode(
    String couponCode,
    BuildContext screenContext,
  ) async {
    if (mounted && !_isScanned) {
      setState(() {
        _isScanned = true;
        _isLoading = true;
      });

      try {
        String token = widget.token;
        String apiUrl =
            'https://api.getflock.io/api/vendor/redeemed-offers/verify/coupon';
        print('Calling Coupon API: $apiUrl with coupon_code: $couponCode');

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'coupon_code': couponCode}),
        );

        setState(() => _isLoading = false);

        String dialogMessage;
        if (response.statusCode == 200) {
          var responseData = jsonDecode(response.body);
          dialogMessage =
              responseData['message'] ?? 'Coupon verified successfully!';
          Fluttertoast.showToast(msg: dialogMessage);
          print('Coupon API Response: $responseData');
        } else if (response.statusCode == 401) {
          dialogMessage = 'Session expired. Please log in again.';
          Fluttertoast.showToast(msg: dialogMessage);
          Navigator.pushReplacementNamed(context, '/login');
          return;
        } else {
          var responseData = jsonDecode(response.body);
          dialogMessage =
              responseData['message'] ??
              'Failed to verify coupon code: ${response.statusCode}';
          print('Coupon API Error: ${response.statusCode} - ${response.body}');
        }

        showDialog(
          context: screenContext,
          barrierDismissible: false,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Coupon Code Verification'),
                content: Text(dialogMessage),
                actions: [
                  TextButton(
                    onPressed: () {
                      print('Dialog OK button pressed');
                      Navigator.of(dialogContext).pop();
                      Navigator.of(screenContext).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      } catch (e, stackTrace) {
        print('Error during coupon API call: $e\n$stackTrace');
        setState(() => _isLoading = false);
        showDialog(
          context: screenContext,
          barrierDismissible: false,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Error'),
                content: Text('An error occurred: $e'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      setState(() {
                        _isScanned = false;
                      });
                    },
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(screenContext).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    }
  }

  void _handleScannedQRCode(String qrCode, BuildContext screenContext) async {
    print('Scanned QR Code: $qrCode for venue_id: ${widget.venueId}');
    if (mounted && !_isScanned) {
      setState(() {
        _isScanned = true;
        _isLoading = true;
      });
      _scannerController.stop();

      try {
        String parsedRedeemId;
        try {
          parsedRedeemId = qrCode.trim();
          if (int.tryParse(parsedRedeemId) == null) {
            final regex = RegExp(r'\d+');
            final match = regex.firstMatch(qrCode);
            if (match != null) {
              parsedRedeemId = match.group(0)!;
            } else {
              throw FormatException(
                'QR code does not contain a valid redeem ID',
              );
            }
          }
          try {
            var jsonData = jsonDecode(qrCode);
            if (jsonData['redeemId'] != null) {
              parsedRedeemId = jsonData['redeemId'].toString();
              if (int.tryParse(parsedRedeemId) == null) {
                throw FormatException(
                  'Redeem ID in JSON is not a valid number',
                );
              }
            }
          } catch (_) {}
        } catch (e) {
          setState(() => _isLoading = false);
          showDialog(
            context: screenContext,
            barrierDismissible: false,
            builder:
                (dialogContext) => AlertDialog(
                  title: const Text('Invalid QR Code'),
                  content: Text(
                    'Invalid QR',
                    style: const TextStyle(color: Colors.red),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        setState(() {
                          _isScanned = false;
                          _scannerController.start();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(screenContext).pop();
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );

          return;
        }

        String venueId = widget.venueId;
        String token = widget.token;

        String apiUrl =
            'https://api.getflock.io/api/vendor/redeemed-offers/$parsedRedeemId/verify';
        print('Calling API: $apiUrl');

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'venue_id': venueId}),
        );

        setState(() => _isLoading = false);

        String dialogMessage;
        if (response.statusCode == 200) {
          var responseData = jsonDecode(response.body);
          dialogMessage =
              responseData['message'] ??
              'Voucher verified successfully for venue ID $venueId!';
          Fluttertoast.showToast(msg: dialogMessage);
          print('API Response: $responseData');

          // Log the check-in event
          await LoggerService.log(
            'Check-In',
            'Customer checked in via QR at venue $venueId',
            LogType.info,
            data: {
              'venue_id': venueId,
              'redeem_id': parsedRedeemId,
              'response': responseData,
            },
          );
        } else if (response.statusCode == 401) {
          dialogMessage = 'Session expired. Please log in again.';
          Fluttertoast.showToast(msg: dialogMessage);
          Navigator.pushReplacementNamed(context, '/login');
          return;
        } else {
          var responseData = jsonDecode(response.body);
          dialogMessage =
              responseData['message'] ??
              'Failed to verify QR Code: ${response.statusCode}';
          print('API Error: ${response.statusCode} - ${response.body}');
        }
        showDialog(
          context: screenContext,
          barrierDismissible: false,
          builder:
              (dialogContext) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                title: const Text(
                  'QR Code Scanned',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                content: Text(dialogMessage, textAlign: TextAlign.center),
                contentPadding: const EdgeInsets.fromLTRB(
                  24.0,
                  20.0,
                  24.0,
                  0,
                ), // Less bottom padding
                actionsPadding: const EdgeInsets.only(
                  right: 8.0,
                  bottom: 8.0,
                ), // Tighten button space
                actionsAlignment:
                    MainAxisAlignment.end, // Align button to the right
                actions: [
                  TextButton(
                    onPressed: () {
                      print('Dialog OK button pressed');
                      Navigator.of(dialogContext).pop();
                      Navigator.of(screenContext).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      } catch (e) {
        print('Error during API call or dialog');
        setState(() => _isLoading = false);
        showDialog(
          context: screenContext,
          barrierDismissible: false,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Error'),
                content: Text(
                  'An error occurred:',
                  style: TextStyle(color: Colors.red), // Display error in red
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(screenContext).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A4CE1),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/back_updated.png', height: 40, width: 34),
          onPressed:
              _isLoading
                  ? null
                  : () {
                    print('AppBar back button pressed');
                    Navigator.pop(context);
                  },
        ),
        title: Text(
          'Scan QR Code',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge!.color,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFF2A4CE1),
      body: Stack(
        children: [
          SizedBox.expand(
            child: Container(
              color: const Color(0xFF2A4CE1),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.of(context).size.height -
                        AppBar().preferredSize.height -
                        MediaQuery.of(context).padding.top,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment:
                        MainAxisAlignment.start, // Changed to start
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(
                          16.0,
                          8.0,
                          16.0,
                          8.0,
                        ), // Reduced vertical padding
                        child: Text(
                          'Please place the QR code within the frame or enter the coupon code below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                      // Rest of your code remains the same...
                      const SizedBox(height: 35), // Reduced from 20
                      SizedBox(
                        width: 280,
                        height: 320,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child:
                                  _isPermissionGranted
                                      ? MobileScanner(
                                        controller: _scannerController,
                                        onDetect: (capture) {
                                          if (!_isScanned) {
                                            final barcodes = capture.barcodes;
                                            if (barcodes.isNotEmpty) {
                                              final qrCode =
                                                  barcodes.first.rawValue ?? '';
                                              _handleScannedQRCode(
                                                qrCode,
                                                context,
                                              );
                                            }
                                          }
                                        },
                                      )
                                      : Stack(
                                        children: [
                                          Container(
                                            color: Colors.black.withOpacity(
                                              0.14,
                                            ),
                                          ),
                                          Container(
                                            color: Colors.white10,
                                            child: Center(
                                              child: Image.asset(
                                                'assets/Bird_Full_Eye_Blinking.gif',
                                                width: 100,
                                                height: 100,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                            ),
                            Container(
                              width: 280,
                              height: 320,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            Positioned(
                              top: -30,
                              left: 250 / 2 - 17,
                              child: Container(
                                width: 60,
                                height: 60,
                                padding: const EdgeInsets.all(1.0),
                                child: Image.asset(
                                  'assets/bird.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4), // Reduced from 5
                      const Text(
                        'Scan QR Code',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 18), // Reduced from 10
                      const Text(
                        '----- OR ----- ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 23), // Reduced from 10
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: TextField(
                          controller: _couponController,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Enter Coupon Code',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.black),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.black),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16), // Reduced from 20
                      ElevatedButton(
                        onPressed:
                            _isLoading
                                ? null
                                : () {
                                  final couponCode =
                                      _couponController.text.trim();
                                  if (couponCode.isEmpty) {
                                    Fluttertoast.showToast(
                                      msg: 'Please enter a coupon code',
                                    );
                                    return;
                                  }
                                  _verifyCouponCode(couponCode, context);
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(
                            255,
                            130,
                            16,
                            1,
                          ),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Stack(
              children: [
                Container(color: Colors.black.withOpacity(0.14)),
                Container(
                  color: Colors.white10,
                  child: Center(
                    child: Image.asset(
                      'assets/Bird_Full_Eye_Blinking.gif',
                      width: 100,
                      height: 100,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    return Platform.isAndroid ? SafeArea(child: scaffold) : scaffold;
  }
}
