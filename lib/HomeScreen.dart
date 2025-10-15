import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flock/qr_code_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flock/custom_scaffold.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class TabDashboard extends StatefulWidget {
  const TabDashboard({super.key});

  @override
  _TabDashboardState createState() => _TabDashboardState();
}

class _TabDashboardState extends State<TabDashboard>
    with WidgetsBindingObserver {
  String averageFeathers = '';
  String totalFeathers = '';
  int todayFeathers = 0;
  int todayVenuePoints = 0;
  String firstName = '';
  String lastName = '';
  bool loader = false;
  bool isVenueListLoaded = false;

  List<Map<String, dynamic>> venueList = [];
  Map<String, dynamic>? selectedVenue;
  bool showVenueDropdown = false;

  List<Map<String, dynamic>> hotelList = [
    {
      'id': 1,
      'slug': 'Check-Ins',
      'category': 'Check-Ins',
      'title': 'Total Check-Ins Today',
      'points': '',
      'img': 'assets/business_checkin.png',
    },
    {
      'id': 2,
      'slug': 'offers',
      'category': 'Offers',
      'title': 'Total Active Offers',
      'points': '',
      'img': 'assets/points.png',
    },
    {
      'id': 3,
      'slug': 'venues',
      'category': 'Venues',
      'title': 'Total Venues',
      'points': '',
      'img': 'assets/business_eggs.png',
    },
    {
      'id': 4,
      'slug': 'faq',
      'category': 'Activities',
      'title': 'See Transaction History',
      'points': '',
      'img': 'assets/feather.png',
    },
  ];

  Timer? _timer;
  String userId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchName();
    getUserId();
    _initializePermissions();
  }

  /* --------- permissions section started -----*/
  List<Map<String, dynamic>> permissions = [];
  bool canAddVenue = false;
  bool canAddOffer = false;
  bool canViewCheckIns = false;
  bool canViewOffers = false;
  bool canViewVenues = false;
  bool canViewTransactionHistory = false;

  Future<void> fetchPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final permissionsString = prefs.getString('permissions');

    if (permissionsString != null) {
      final List<dynamic> decoded = jsonDecode(permissionsString);
      permissions = List<Map<String, dynamic>>.from(decoded);

      print('Loaded permissions: $permissions');
    }
  }

  bool hasPermissionToUser(String permissionName) {
    final normalized = permissionName.toLowerCase().replaceAll('_', ' ');

    return permissions.any(
      (p) => (p['name']?.toString().toLowerCase() ?? '') == normalized,
    );
  }

  Future<void> checkPermission() async {
    setState(() {
      if (permissions.isEmpty) {
        print("User has all permissions.");
        canAddOffer = true;
        canAddVenue = true;
        canViewCheckIns = true;
        canViewOffers = true;
        canViewVenues = true;
        canViewTransactionHistory = true;
        return;
      }
      canAddVenue = hasPermissionToUser('Add venue');
      canAddOffer = hasPermissionToUser('Add offer');
      canViewCheckIns = hasPermissionToUser('List checkin-history');
      canViewOffers = hasPermissionToUser('List offers');
      canViewVenues = hasPermissionToUser('View venue');
      canViewTransactionHistory = hasPermissionToUser('List transactions');

      if (canAddVenue) print("✅ User can add venues.");
      if (canAddOffer) print("✅ User can add offer.");
      if (canViewCheckIns) print("✅ User can view check-ins.");
      if (canViewOffers) print("✅ User can offers.");
      if (canViewVenues) print("✅ User can view venues.");
      if (canViewTransactionHistory)
        print("✅ User can view transaction history.");

      if (!canAddVenue &&
          !canAddOffer &&
          !canViewCheckIns &&
          !canViewOffers &&
          !canViewVenues &&
          !canViewTransactionHistory) {
        print("❌ User has no permission to access venues.");
      }
    });
  }

  Future<void> _initializePermissions() async {
    await fetchPermissions();
    checkPermission();
  }

  /* --------- permissions section endede -----*/

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      var status = await Permission.camera.status;
      print("App resumed; camera permission status: $status");
    }
  }

  Future<void> fetchName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        firstName = prefs.getString('firstName') ?? '';
        lastName = prefs.getString('lastName') ?? '';
      });
    }
  }

  Future<void> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userid') ?? '';
    if (averageFeathers.isEmpty && venueList.isEmpty) {
      await dashboardApi();
      await getVenueList();
    }
  }

  void startLoader() {
    if (mounted) {
      setState(() {
        loader = true;
      });
    }
    _timer?.cancel();
    _timer = Timer(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          loader = false;
        });
      }
    });
  }

  Future<void> dashboardApi() async {
    startLoader();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      Fluttertoast.showToast(msg: 'No token found, please login again.');
      if (mounted) setState(() => loader = false);
      return;
    }
    final url = Uri.parse("https://api.getflock.io/api/vendor/dashboard");
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (mounted) setState(() => loader = false);
        Fluttertoast.showToast(
          msg: 'No internet connection',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (mounted) {
        setState(() {
          loader = false;
        });
      }
      print("Dashboard api response data : ${response.body}");
      if (response.statusCode == 200) {
        final responseJson = json.decode(response.body);
        if (responseJson != null && responseJson['status'] == 'success') {
          final data = responseJson['data'];
          if (mounted) {
            setState(() {
              averageFeathers = data['averageFeathers']?.toString() ?? '';
              totalFeathers = data['totalFeathers']?.toString() ?? '';
              todayFeathers =
                  int.tryParse(data['today_feathers']?.toString() ?? '0') ?? 0;
              todayVenuePoints =
                  int.tryParse(data['today_venue_points']?.toString() ?? '0') ??
                  0;
              hotelList[0]['points'] =
                  '${int.tryParse(data['today_checkins']?.toString() ?? '0') ?? 0}';
              hotelList[1]['points'] =
                  '${int.tryParse(data['offers_count']?.toString() ?? '0') ?? 0}';
              hotelList[2]['points'] =
                  '${int.tryParse(data['venues_count']?.toString() ?? '0') ?? 0}';
              hotelList[3]['points'] =
                  '${int.tryParse(data['history_number']?.toString() ?? '0') ?? 0}';
            });
          }
        } else {
          Fluttertoast.showToast(msg: responseJson['message'] ?? 'Error');
        }
      } else {
        print('Error while DashBoard Api performing: ${response.body}');
        Fluttertoast.showToast(
          msg: 'Error while DashBoard Api performing: ${response.statusCode}',
        );
      }
    } on SocketException {
      if (mounted) setState(() => loader = false);
      Fluttertoast.showToast(
        msg: 'No internet connection',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          loader = false;
        });
      }
      print('Error while DashBoard Api performing: $e');
      Fluttertoast.showToast(msg: 'Error while DashBoard Api performing: $e');
    }
  }

  Future<void> getVenueList() async {
    startLoader();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      Fluttertoast.showToast(msg: 'No token found, please login again.');
      setState(() {
        loader = false;
        isVenueListLoaded = true;
      });
      return;
    }
    final url = Uri.parse("https://api.getflock.io/api/vendor/venues");
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        setState(() {
          loader = false;
          isVenueListLoaded = true;
        });
        Fluttertoast.showToast(
          msg: 'No internet connection',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print("hiiiiiii");
      print('Response in veneu Api:${response.body}');
      setState(() {
        loader = false;
        isVenueListLoaded = true;
      });
      if (response.statusCode == 200) {
        print("api vendor venue1111111");
        final responseJson = json.decode(response.body);
        if (responseJson != null && responseJson['status'] == 'success') {
          setState(() {
            venueList = List<Map<String, dynamic>>.from(
              responseJson['data'] ?? [],
            );
            if (venueList.isNotEmpty) {
              selectedVenue = venueList[0];
            }
          });
        } else {
          Fluttertoast.showToast(
            msg: responseJson['message'] ?? 'Error fetching venues',
          );
        }
      } else {
        print('Error in veneu Api:${response.body}');
        Fluttertoast.showToast(
          msg: 'Error in veneu Api:${response.statusCode}',
        );
      }
    } on SocketException {
      setState(() {
        loader = false;
        isVenueListLoaded = true;
      });
      Fluttertoast.showToast(
        msg: 'No internet connection',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() {
        loader = false;
        isVenueListLoaded = true;
      });
      print('Error in veneu Api: $e');
      Fluttertoast.showToast(msg: 'Error in veneu Api: $e');
    }
  }

  bool hasPermission(String permission) {
    return true;
  }

  String getPermissionName(String field) {
    switch (field) {
      case "offers":
        return "create_offer";
      case "Check-Ins":
        return "checkins_history";
      case "feathers":
        return "feathers_history";
      case "venues":
        return "venues_list";
      default:
        return "";
    }
  }

  Future<void> clickCard(Map<String, dynamic> item) async {
    if (!hasPermission(getPermissionName(item['slug']))) {
      Fluttertoast.showToast(msg: "You don't have access to this feature!");
      return;
    }
    String slug = item['slug'];
    if (slug == "offers" && canViewOffers) {
      setState(() {});
      Navigator.pushNamed(context, '/offers');
    } else if (slug == "Check-Ins" && canViewCheckIns) {
      setState(() {});

      Navigator.pushNamed(context, '/tab_checkin');
    } else if (slug == "feathers") {
      setState(() {});

      await totalFeatherApi();
    } else if (slug == "venues" && canViewVenues) {
      setState(() {});

      Navigator.pushNamed(context, '/tab_egg');
    } else if (slug == "faq" && canViewTransactionHistory) {
      setState(() {});

      Navigator.pushNamed(context, '/history');
    }
  }

  Future<void> totalFeatherApi() async {
    startLoader();
    var url = Uri.parse("https://yourserver.com/dashboard");
    var request = http.MultipartRequest('POST', url);
    request.fields['user_id'] = userId;
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        setState(() => loader = false);
        Fluttertoast.showToast(
          msg: 'No internet connection',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
      var response = await request.send();
      var responseString = await response.stream.bytesToString();
      var responseJson = json.decode(responseString);
      setState(() {
        loader = false;
      });
      if (responseJson != null && responseJson['status'] == 'success') {
        Navigator.pushNamed(
          context,
          '/feathers',
          arguments: {
            'totalfeathers': responseJson['totalfeathers'],
            'totalvenuepoints': responseJson['total_venue_points'],
          },
        );
      } else {
        Fluttertoast.showToast(msg: responseJson['message'] ?? 'Error');
      }
    } on SocketException {
      setState(() => loader = false);
      Fluttertoast.showToast(
        msg: 'No internet connection',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() {
        loader = false;
      });
      print('Error while runing total feather api: $e');
      Fluttertoast.showToast(msg: 'Error while runing total feather api: $e');
    }
  }

  Future<void> verifyOffer() async {
    if (!hasPermission('verify_voucher')) {
      Fluttertoast.showToast(msg: 'Permission Denied!');
      return;
    }
    if (selectedVenue == null) {
      Fluttertoast.showToast(msg: 'Please select a venue first!');
      return;
    }
    var status = await Permission.camera.status;
    print("Initial camera permission status: $status");
    if (status.isDenied) {
      status = await Permission.camera.request();
      print("Camera permission status after request: $status");
    }
    if (status.isGranted) {
      _navigateToQRScanScreen(selectedVenue!['id'].toString());
    } else if (status.isPermanentlyDenied) {
      Fluttertoast.showToast(
        msg:
            'Camera permission is permanently denied. Please enable it in settings.',
      );
      await openAppSettings();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        var newStatus = await Permission.camera.status;
        if (newStatus.isGranted) {
          _navigateToQRScanScreen(selectedVenue!['id'].toString());
        }
      });
    } else {
      Fluttertoast.showToast(msg: 'Camera Permission Denied!');
    }
  }

  Future<void> _navigateToQRScanScreen(String venueId) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('access_token');
    if (token == null) {
      Fluttertoast.showToast(msg: 'No token found. Please log in.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScanScreen(venueId: venueId, token: token),
      ),
    ).then((qrCode) {
      if (qrCode != null) {
        _handleScannedQRCode(qrCode, venueId);
      }
    });
  }

  Future<void> _handleScannedQRCode(String qrCode, String venueId) async {
    startLoader();
    final token = await SharedPreferences.getInstance().then(
      (prefs) => prefs.getString('access_token'),
    );
    final url = Uri.parse("https://api.getflock.io/api/vendor/verify-voucher");
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        setState(() => loader = false);
        Fluttertoast.showToast(
          msg: 'No internet connection',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
      print("apiverift called");
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'qr_code': qrCode, 'venue_id': venueId}),
      );
      print("response123: ${response.body}");
      setState(() => loader = false);
      if (response.statusCode == 200) {
        Fluttertoast.showToast(msg: 'Voucher verified successfully!');
      } else {
        Fluttertoast.showToast(msg: 'Error verifying voucher');
      }
    } on SocketException {
      setState(() => loader = false);
      Fluttertoast.showToast(
        msg: 'No internet connection',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() => loader = false);
      print("error111: $e");
      Fluttertoast.showToast(msg: 'Error: $e');
    }
  }

  // Generate QR code link with automatic app store fallback
  Future<String> _generateQRCodeLink(String venueId) async {
    // For now, return the existing URL format
    // You can implement the full Branch SDK integration later
    return 'https://flockloyalty.app.link/?venue_id=$venueId';
  }

  Widget customVenueDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF1E1E1E)
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                showVenueDropdown = !showVenueDropdown;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF1E1E1E)
                        : Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedVenue == null
                        ? "Select Venue"
                        : selectedVenue!['name'] ?? "Select Venue",
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  Icon(
                    showVenueDropdown
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down,
                    color: Theme.of(context).iconTheme.color,
                  ),
                ],
              ),
            ),
          ),
          if (showVenueDropdown)
            Container(
              constraints: BoxConstraints(maxHeight: 35.0 * 5),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF1E1E1E)
                        : Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(5),
                  bottomRight: Radius.circular(5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: venueList.length,
                        itemBuilder: (context, index) {
                          final venue = venueList[index];
                          final isSelected =
                              selectedVenue != null &&
                              selectedVenue!['id'].toString() ==
                                  venue['id'].toString();
                          return InkWell(
                            onTap: () {
                              setState(() {
                                selectedVenue = venue;
                                showVenueDropdown = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 6,
                              ),
                              color:
                                  isSelected
                                      ? Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Color(0xFF2C2C2C)
                                          : Theme.of(
                                            context,
                                          ).colorScheme.primary.withOpacity(0.1)
                                      : Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Color(0xFF1E1E1E)
                                      : Colors.transparent,
                              child: Text(
                                venue['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 15,
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.bodyLarge!.color,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget venueListWithQRCodes() {
    if (!hasPermission('verify_voucher')) {
      return const SizedBox.shrink();
    }
    if (!isVenueListLoaded) {
      return const SizedBox.shrink();
    }
    if (venueList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(10.0),
        child: Center(
          child: Text(
            'You don\'t have any venues yet, please add a venue by clicking on the "Bird Image" at the bottom.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        customVenueDropdown(),
        if (selectedVenue != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF242424)
                          : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.05)
                            : Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                  // boxShadow:
                  //     Theme.of(context).brightness == Brightness.dark
                  //         ? [
                  //           BoxShadow(
                  //             color: Colors.black.withOpacity(0.5),
                  //             spreadRadius: -2,
                  //             blurRadius: 12,
                  //             offset: const Offset(0, 4),
                  //           ),
                  //           BoxShadow(
                  //             color: Colors.black.withOpacity(0.3),
                  //             spreadRadius: 0,
                  //             blurRadius: 4,
                  //             offset: const Offset(0, 2),
                  //           ),
                  //         ]
                  //         : [
                  //           BoxShadow(
                  //             color: Colors.black.withOpacity(0.08),
                  //             spreadRadius: 0,
                  //             blurRadius: 8,
                  //             offset: const Offset(0, 4),
                  //           ),
                  //           BoxShadow(
                  //             color: Colors.black.withOpacity(0.05),
                  //             spreadRadius: -1,
                  //             blurRadius: 2,
                  //             offset: const Offset(0, 1),
                  //           ),
                  //         ],
                ),
                child: FutureBuilder<String>(
                  future: _generateQRCodeLink(selectedVenue!['id'].toString()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final qrData =
                        snapshot.data ??
                        'https://flockloyalty.app.link/?venue_id=${selectedVenue!['id']}';

                    return QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: MediaQuery.of(context).size.width * .4,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Theme.of(context).colorScheme.surface,
                      padding: const EdgeInsets.all(8.0),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceWidth = MediaQuery.of(context).size.width;
    final scaffold = CustomScaffold(
      canAddOffer: canAddOffer,
      canAddVenue: canAddVenue,
      currentIndex: 0,
      body: Stack(
        children: [
          Container(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF1E1E1E)
                    : Theme.of(context).scaffoldBackgroundColor,
            padding: EdgeInsets.symmetric(horizontal: deviceWidth * 0.023),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: Platform.isIOS ? 20 : 5,
                    bottom: Platform.isIOS ? 10 : 5,
                    left: Platform.isIOS ? 15 : 5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Hello, ',
                            style: TextStyle(
                              fontSize: 18,
                              color:
                                  Theme.of(context).textTheme.bodyLarge!.color,
                            ),
                          ),
                          Text(
                            '$firstName $lastName',
                            style: TextStyle(
                              fontSize: 18,
                              color:
                                  Theme.of(context).textTheme.bodyLarge!.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Image.asset(
                          'assets/scan_qr.png',
                          width: Platform.isIOS ? 45 : 40,
                          height: Platform.isIOS ? 45 : 40,
                        ),
                        onPressed: verifyOffer,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: Platform.isIOS ? 5 : 5),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            padding: EdgeInsets.all(deviceWidth * 0.023),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing:
                                      MediaQuery.of(context).size.height *
                                      0.016,
                                  crossAxisSpacing: deviceWidth * 0.04,
                                  childAspectRatio:
                                      deviceWidth /
                                      (MediaQuery.of(context).size.height *
                                          0.4),
                                  mainAxisExtent:
                                      MediaQuery.of(context).size.width * .4,
                                ),
                            itemCount: hotelList.length,
                            itemBuilder: (context, index) {
                              final item = hotelList[index];
                              return GestureDetector(
                                onTap: () => clickCard(item),
                                child: Container(
                                  alignment: Alignment.center,
                                  margin: EdgeInsets.symmetric(
                                    vertical:
                                        MediaQuery.of(context).size.height *
                                        0.0025,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Color(0xFF242424)
                                            : Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white.withOpacity(0.05)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .outline
                                                  .withOpacity(0.1),
                                      width: 1,
                                    ),
                                    boxShadow:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.5,
                                                ),
                                                spreadRadius: -2,
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.3,
                                                ),
                                                spreadRadius: 0,
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                            : [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.08,
                                                ),
                                                spreadRadius: 0,
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.05,
                                                ),
                                                spreadRadius: -1,
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical:
                                          MediaQuery.of(context).size.height *
                                          0.020,
                                      horizontal: deviceWidth * 0.03,
                                    ),
                                    child: Stack(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Image.asset(
                                                  item['img'],
                                                  width: deviceWidth * 0.06,
                                                  height: deviceWidth * 0.06,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    item['category'],
                                                    style: TextStyle(
                                                      fontSize:
                                                          deviceWidth * 0.04,
                                                      color:
                                                          Theme.of(context)
                                                              .textTheme
                                                              .titleMedium!
                                                              .color,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    softWrap: true,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.visible,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                              height:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.01,
                                            ),
                                            Center(
                                              child: Text(
                                                item['title'],
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: deviceWidth * 0.03,
                                                  color:
                                                      Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium!
                                                          .color,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(
                                              height:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.01,
                                            ),
                                            Center(
                                              child: Text(
                                                item['points'],
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: deviceWidth * 0.08,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Positioned(
                                          top: -10,
                                          right: -10,
                                          child: IconButton(
                                            icon: Image.asset(
                                              'assets/side_arrow.png',
                                              width: deviceWidth * 0.035,
                                              height: deviceWidth * 0.035,
                                            ),
                                            onPressed: () => clickCard(item),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 15),
                        venueListWithQRCodes(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (loader)
            Stack(
              children: [
                Container(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.5)
                          : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.2),
                ),
                Container(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.3)
                          : Theme.of(
                            context,
                          ).colorScheme.surface.withOpacity(0.1),
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
