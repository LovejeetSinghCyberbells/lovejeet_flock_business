// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:qr_code_scanner/qr_code_scanner.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// class QRCodeScreen extends StatefulWidget {
//   const QRCodeScreen({Key? key}) : super(key: key);

//   @override
//   State<QRCodeScreen> createState() => _QRCodeScreenState();
// }

// class _QRCodeScreenState extends State<QRCodeScreen> {
//   final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
//   QRViewController? controller;
//   bool isLoading = false;

//   @override
//   void reassemble() {
//     super.reassemble();
//     if (Platform.isAndroid) {
//       controller?.pauseCamera();
//     }
//     controller?.resumeCamera();
//   }

//   /// Called when the QRView is created.
//   void _onQRViewCreated(QRViewController controller) {
//     this.controller = controller;
//     controller.scannedDataStream.listen((scanData) {
//       // Once we have a result, pause scanning.
//       controller.pauseCamera();
//       _onSuccess(scanData.code);
//     });
//   }

//   /// Processes the scanned data.
//   void _onSuccess(String? code) {
//     if (code == null) return;
//     debugPrint("Scan Done: $code");
//     // Assume the scanned data is comma-separated with at least 6 parts.
//     List<String> parts = code.split(',');
//     if (parts.length < 6) {
//       Fluttertoast.showToast(msg: "Invalid QR Code");
//       controller?.resumeCamera();
//       return;
//     }
//     // Extract values (adjust indexes as needed)
//     String userId = parts[0];
//     String venueId = parts[1];
//     String offerId = parts[2];
//     // You can extract other parts as needed (e.g. parts[3], parts[4], parts[5])
//     _verifyOffer(userId, venueId, offerId);
//   }

//   /// Calls your API to verify the redeem offer.
//   Future<void> _verifyOffer(String userId, String venueId, String offerId) async {
//     setState(() {
//       isLoading = true;
//     });
//     // Replace with your actual endpoint for verifying redeem offers.
//     final url = Uri.parse("https://api.getflock.io/api/vendor/verify_redeem_offer");
//     // Prepare the request payload.
//     final payload = {
//       "user_id": userId,
//       "venue_id": venueId,
//       "offer_id": offerId,
//     };

//     try {
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           // Add token if required:
//           // 'Authorization': 'Bearer <your_token>',
//         },
//         body: jsonEncode(payload),
//       );
//       setState(() {
//         isLoading = false;
//       });
//       if (response.statusCode == 200) {
//         final responseJson = jsonDecode(response.body);
//         if (responseJson != null && responseJson['status'] == 'success') {
//           Fluttertoast.showToast(msg: responseJson['message'] ?? "Success");
//           _showSuccessDialog();
//         } else {
//           Fluttertoast.showToast(msg: responseJson['message'] ?? "Verification failed");
//           controller?.resumeCamera();
//         }
//       } else {
//         Fluttertoast.showToast(msg: "Error: ${response.statusCode}");
//         controller?.resumeCamera();
//       }
//     } catch (e) {
//       setState(() {
//         isLoading = false;
//       });
//       Fluttertoast.showToast(msg: "Network error: $e");
//       controller?.resumeCamera();
//     }
//   }

//   /// Shows a success dialog after verification.
//   void _showSuccessDialog() {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text("Success"),
//           content: const Text("Check in Successfully"),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop(); // Close dialog
//                 Navigator.of(context).pop(); // Return to previous screen
//               },
//               child: const Text("DONE"),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   void dispose() {
//     controller?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // For background and instructions, we use a Stack.
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               // Top bar with back button and title.
//               Container(
//                 padding: EdgeInsets.only(top: Platform.isIOS ? 40 : 20, left: 16, right: 16),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     IconButton(
//                       icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                       },
//                     ),
//                     const Text(
//                       "Scan QR Code",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 20,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     const SizedBox(width: 30),
//                   ],
//                 ),
//               ),
//               // QR View
//               Expanded(
//                 child: QRView(
//                   key: qrKey,
//                   onQRViewCreated: _onQRViewCreated,
//                   overlay: QrScannerOverlayShape(
//                     borderColor: const Color.fromRGBO(255, 130, 16, 1),
//                     borderRadius: 10,
//                     borderLength: 30,
//                     borderWidth: 10,
//                     cutOutSize: MediaQuery.of(context).size.width * 0.8,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               const Text(
//                 "Scanning Code ...",
//                 style: TextStyle(color: Colors.white, fontSize: 16),
//               ),
//               const SizedBox(height: 20),
//             ],
//           ),
//           if (isLoading)
//             Container(
//               color: Colors.black54,
//               child: const Center(child: CircularProgressIndicator()),
//             ),
//           // Optionally overlay an image (for example, your bird logo) in the center of the QR view:
//           Positioned(
//             top: MediaQuery.of(context).size.height * 0.35,
//             left: (MediaQuery.of(context).size.width - 70) / 2,
//             child: Image.asset(
//               'assets/bird.png',
//               width: 70,
//               height: 70,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
