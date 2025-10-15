import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:flock/add_offer.dart';
import 'package:flock/edit_venue.dart';
import 'package:flock/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flock/HomeScreen.dart';
import 'package:flock/custom_scaffold.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Design tokens
class Design {
  static Color get white => Colors.white;
  static Color get black => Colors.black;
  static const Color darkPink = Color(0xFFD81B60);
  static Color get lightGrey => Colors.grey;
  static const Color lightBlue = Color(0xFF2A4CE1);
  static const Color lightPink = Color(0xFFFFE9ED);
  static Color get primaryColorOrange => AppColors.primary;
  static const double font11 = 11;
  static const double font12 = 12;
  static const double font13 = 13;
  static const double font15 = 15;
  static const double font17 = 17;
  static const double font20 = 20;

  static Color get lightxious => AppColors.primary.withOpacity(0.2);
  static Color get blue => Colors.blue;

  // Dark mode colors
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF242424);
  static const Color darkBorder = Color(0xFF3E3E3E);

  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : white;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : white;
  }

  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? white : black;
  }

  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : Colors.grey.withOpacity(0.3);
  }
}

// Global images
class GlobalImages {
  static const String location = 'assets/location.png';
}

// Server endpoints
class Server {
  static const String categoryList =
      'https://api.getflock.io/api/vendor/categories';
  static const String getProfile = 'https://api.getflock.io/api/vendor/profile';
  static const String getVenueData =
      'https://api.getflock.io/api/vendor/venues';
  static const String removeVenue = 'https://api.getflock.io/api/vendor/venues';
  static const String updateVenue = 'https://api.getflock.io/api/vendor/venues';
  static const String venueList = 'https://api.getflock.io/api/vendor/venues';
}

// Permissions placeholder
class UserPermissions {
  static void getAssignedPermissions(String? userId) {}
  static bool hasPermission(String permission) => true;
}

// Reusable card wrapper widget
Widget cardWrapper({
  required Widget child,
  double borderRadius = 10,
  double elevation = 5,
  Color? color,
  BuildContext? context,
}) {
  return Container(
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: elevation,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class TabEggScreen extends StatefulWidget {
  const TabEggScreen({super.key});

  @override
  State<TabEggScreen> createState() => _TabEggScreenState();
}

class _TabEggScreenState extends State<TabEggScreen> {
  bool loader = false;
  bool dialogAlert = false;
  String removeVenueId = '';
  String greeting = '';
  String firstName = '';
  String lastName = '';
  List<dynamic> categoryList = [];
  int cardPosition = 0;
  List<dynamic> allData = [];
  Timer? _timer;
  Timer? _debounce;

  /* --------- permissions section started -----*/
  List<Map<String, dynamic>> permissions = [];
  bool canViewVenue = false;
  bool canAddVenue = false;
  bool canAddOffer = false;
  bool canEditVenue = false;
  bool canRemoveVenue = false;

  Future<void> fetchPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final permissionsString = prefs.getString('permissions');

    if (permissionsString != null) {
      final List<dynamic> decoded = jsonDecode(permissionsString);
      permissions = List<Map<String, dynamic>>.from(decoded);

      print('Loaded permissions: $permissions');
    }
  }

  bool hasPermission(String permissionName) {
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
        canEditVenue = true;
        canRemoveVenue = true;
        canViewVenue = true;
        return;
      }
      canViewVenue = hasPermission('View venue');
      canAddVenue = hasPermission('Add venue');
      canAddOffer = hasPermission('Add offer');
      canEditVenue = hasPermission('Edit venue');
      canRemoveVenue = hasPermission('Remove venue');

      if (canViewVenue) print("✅ User can view venues.");
      if (canAddVenue) print("✅ User can add venues.");
      if (canAddOffer) print("✅ User can add offer.");
      if (canEditVenue) print("✅ User can edit venues.");
      if (canRemoveVenue) print("✅ User can remove venues.");

      if (!canViewVenue &&
          !canAddVenue &&
          !canEditVenue &&
          !canRemoveVenue &&
          !canAddOffer) {
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
  void initState() {
    super.initState();
    computeGreeting();
    fetchInitialData();

    _initializePermissions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void computeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }
  }

  Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? '';
  }

  Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userid') ?? '';
  }

  void startLoader() {
    setState(() => loader = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 20), () {
      setState(() => loader = false);
    });
  }

  Future<Map<String, dynamic>> makeApiRequest({
    required String url,
    required Map<String, String> headers,
    Map<String, String>? queryParams,
  }) async {
    try {
      // Check for internet connection before making the API call
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        Fluttertoast.showToast(
          msg: 'No internet connection',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        throw Exception('No internet connection');
      }
      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      http.Response response;
      try {
        response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 20));
      } on SocketException {
        Fluttertoast.showToast(
          msg: 'No internet connection',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        throw Exception('No internet connection');
      }
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchInitialData() async {
    try {
      final userId = await getUserId();
      await Future.wait([getProfile(userId), getCategoryList(userId)]);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error initializing data: $e');
    }
  }

  Future<void> getProfile(String userId) async {
    setState(() => loader = true);
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
      final token = await getToken();
      if (token.isEmpty) throw Exception('No authentication token');

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      final response = await makeApiRequest(
        url: Server.getProfile,
        headers: headers,
      );

      setState(() {
        loader = false;
        firstName = response['data']['first_name'] ?? '';
        lastName = response['data']['last_name'] ?? '';
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('firstName', firstName);
          prefs.setString('lastName', lastName);
        });
      });
    } catch (e) {
      setState(() => loader = false);
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        firstName = prefs.getString('firstName') ?? 'User';
        lastName = prefs.getString('lastName') ?? '';
      });
    }
  }

  Future<void> getCategoryList(String userId) async {
    setState(() => loader = true);
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
      final token = await getToken();
      if (token.isEmpty) throw Exception('No authentication token');

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      final response = await makeApiRequest(
        url: Server.categoryList,
        headers: headers,
      );

      setState(() {
        categoryList = response['data'] ?? [];
        loader = false;
        if (categoryList.isNotEmpty) {
          cardPosition = 0;
          getVenueData(userId, categoryList[cardPosition]['id'].toString());
        }
      });
    } catch (e) {
      setState(() => loader = false);
      Fluttertoast.showToast(msg: 'Failed to load categories: $e');
    }
  }

  Future<void> getVenueData(String userId, String categoryId) async {
    setState(() => loader = true);
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
      final token = await getToken();
      if (token.isEmpty) throw Exception('No authentication token');

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      final response = await makeApiRequest(
        url: Server.getVenueData,
        headers: headers,
        queryParams: {'category_id': categoryId},
      );

      setState(() {
        allData = response['data'] ?? [];
        loader = false;
      });
    } catch (e) {
      setState(() {
        allData = [];
        loader = false;
      });
      Fluttertoast.showToast(msg: 'Failed to load venues: $e');
    }
  }

  void clickCategoryItem(dynamic item, int index) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        cardPosition = index;
        loader = true;
      });
      getUserId().then((uid) => getVenueData(uid, item['id'].toString()));
    });
  }

  Future<void> removeVenueBtn() async {
    setState(() => loader = true);
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
      final token = await getToken();
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      final response = await http.delete(
        Uri.parse('${Server.removeVenue}/$removeVenueId'),
        headers: headers,
      );

      final responseData =
          response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode == 200) {
        setState(() {
          allData.removeWhere(
            (element) => element['id'].toString() == removeVenueId,
          );
          dialogAlert = false;
          loader = false;
        });
        Fluttertoast.showToast(
          msg: responseData['message'] ?? 'Venue removed successfully',
          toastLength: Toast.LENGTH_LONG,
        );
        final userId = await getUserId();
        if (categoryList.isNotEmpty) {
          getVenueData(userId, categoryList[cardPosition]['id'].toString());
        }
      } else {
        var errorMessage =
            responseData['message'] ??
            'Failed to remove venue (Status: ${response.statusCode})';
        throw Exception(errorMessage);
      }
    } catch (e) {
      setState(() => loader = false);
      Fluttertoast.showToast(
        msg: 'Failed to remove venue: ${e.toString()}',
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void editVenue(Map<String, dynamic> item) {
    if (!UserPermissions.hasPermission('edit_venue')) {
      Fluttertoast.showToast(msg: "You don't have access to this feature!");
      return;
    }
    final categoryId =
        item['category_id']?.toString() ??
        categoryList[cardPosition]['id'].toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditVenueScreen(
              venueData: Map<String, dynamic>.from(item),
              categoryId: categoryId,
            ),
      ),
    ).then((updatedVenue) {
      if (updatedVenue != null && updatedVenue is Map<String, dynamic>) {
        setState(() {
          final index = allData.indexWhere(
            (v) => v['id'].toString() == updatedVenue['id'].toString(),
          );
          if (index != -1) {
            allData[index] = Map<String, dynamic>.from(updatedVenue);
          } else {
            allData.add(Map<String, dynamic>.from(updatedVenue));
          }
        });
        getUserId().then((uid) => getVenueData(uid, categoryId));
      }
    });
  }

  void qrCodeBtn(Map<String, dynamic> item) {
    final String qrData = item['qrData'] ?? item['id'].toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor:
              Theme.of(context).brightness == Brightness.dark
                  ? Design.darkSurface
                  : Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Design.darkBorder
                      : Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "QR Code",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black54,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Design.darkBorder
                              : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void locationBtn(String lat, String lon, String label) {
    final latNum = double.tryParse(lat) ?? 0.0;
    final lonNum = double.tryParse(lon) ?? 0.0;
    final scheme = Platform.isIOS ? 'maps://?daddr=' : 'geo:';
    final uri = '$scheme$latNum,$lonNum';
  }

  Widget buildCategoryItem(dynamic item, int index) {
    final isSelected = (cardPosition == index);
    final colors = [
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.primary.withOpacity(0.05)
          : AppColors.primary.withOpacity(0.1),
      Theme.of(context).brightness == Brightness.dark
          ? Colors.blue.withOpacity(0.05)
          : Colors.blue.withOpacity(0.1),
      Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.withOpacity(0.05)
          : Colors.grey.withOpacity(0.1),
      Theme.of(context).brightness == Brightness.dark
          ? Colors.yellow.withOpacity(0.05)
          : Colors.yellow.withOpacity(0.1),
    ];
    final bgColor = colors[index % colors.length];

    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth * 0.07;

    return GestureDetector(
      onTap: () => clickCategoryItem(item, index),
      child: Container(
        width: screenWidth * 0.18,
        margin: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.002,
          vertical: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.surface
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border:
                    isSelected
                        ? Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.2),
                        )
                        : null,
              ),
              padding: EdgeInsets.all(screenWidth * 0.020),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  cardWrapper(
                    borderRadius: 40,
                    elevation: isSelected ? 0 : 5,
                    color: bgColor,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: ClipOval(
                          child: SizedBox(
                            width: iconSize,
                            height: iconSize,
                            child: Image.network(
                              item['icon'] ?? 'https://picsum.photos/50',
                              fit: BoxFit.cover,
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color.fromRGBO(255, 130, 16, 1)
                                      : null,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      IconTheme.merge(
                                        data: IconThemeData(
                                          color:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Colors.orange
                                                  : Theme.of(
                                                    context,
                                                  ).iconTheme.color,
                                        ),
                                        child: Icon(
                                          Icons.error,
                                          size: iconSize * 0.8,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.010),
                  SizedBox(
                    width: screenWidth * 0.2,
                    child: Text(
                      item['name'] ?? '',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: screenWidth * 0.03,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildVenueItem(Map<String, dynamic> item) {
    return cardWrapper(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                item['images'] != null && item['images'].isNotEmpty
                    ? item['images'].last['medium_image']
                    : 'https://picsum.photos/90',
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) => Container(
                      width: 90,
                      height: 90,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.1),
                      child: Icon(
                        Icons.image_not_supported,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] ?? 'No Name',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontSize: Design.font17,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (item['approval'] == '0')
                        Text(
                          '(In Review)',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontSize: Design.font13,
                            color: Design.darkPink,
                          ),
                        )
                      else
                        InkWell(
                          onTap: () => qrCodeBtn(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Design.darkSurface
                                      : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Design.darkBorder
                                        : Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.qr_code,
                                  size: 16,
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.blue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'QR Code',
                                  style: TextStyle(
                                    fontSize: Design.font12,
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Image.asset(
                          GlobalImages.location,
                          width: 14,
                          height: 14,
                          color: Theme.of(context).iconTheme.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap:
                              () => locationBtn(
                                item['lat']?.toString() ?? '0.0',
                                item['lon']?.toString() ?? '0.0',
                                item['location'] ?? 'Unknown',
                              ),
                          child: Text(
                            item['location'] ?? 'No location',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontSize: Design.font12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Image.asset(
                        'assets/date_time.png',
                        width: 14,
                        height: 14,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item['posted_at'] ?? '',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontSize: Design.font12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      canRemoveVenue == false
                          ? Container()
                          : SizedBox(
                            height: 32,

                            child: cardWrapper(
                              borderRadius: 5,
                              elevation: 2,
                              color: Colors.red,
                              child: InkWell(
                                onTap: () {
                                  if (!UserPermissions.hasPermission(
                                    'remove_venue',
                                  )) {
                                    Fluttertoast.showToast(
                                      msg:
                                          "You don't have access to this feature!",
                                    );
                                    return;
                                  }
                                  setState(() {
                                    removeVenueId = item['id'].toString();
                                    dialogAlert = true;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.delete,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Delete',
                                        style: TextStyle(
                                          fontSize: Design.font13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      const SizedBox(width: 15),
                      canEditVenue == false
                          ? Container()
                          : SizedBox(
                            height: 32,

                            child: cardWrapper(
                              borderRadius: 5,
                              elevation: 2,
                              color: Theme.of(context).colorScheme.primary,
                              child: InkWell(
                                onTap: () => editVenue(item),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/edit.png',
                                        width: 16,
                                        height: 16,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Edit Info',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.copyWith(
                                          fontSize: Design.font13,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = CustomScaffold(
      canAddOffer: canAddOffer,
      canAddVenue: canAddVenue,
      currentIndex: 1,
      body: Stack(
        children: [
          Column(
            children: [
              cardWrapper(
                borderRadius: 10,
                elevation: 5,
                color: Design.getSurfaceColor(context),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TabDashboard(),
                                ),
                              );
                            },
                            child: Image.asset(
                              'assets/back_updated.png',
                              height: 40,
                              width: 34,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                "All Venues",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Design.getTextColor(context),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$greeting, ',
                                        style: TextStyle(
                                          fontSize: Design.font15,
                                          fontWeight: FontWeight.w400,
                                          color: Design.getTextColor(context),
                                        ),
                                      ),
                                      TextSpan(
                                        text: '$firstName $lastName',
                                        style: TextStyle(
                                          fontSize: Design.font15,
                                          fontWeight: FontWeight.bold,
                                          color: Design.getTextColor(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      height: MediaQuery.of(context).size.height * 0.16,
                      child:
                          categoryList.isEmpty
                              ? const Center()
                              : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                itemCount: categoryList.length,
                                itemBuilder: (context, index) {
                                  final item = categoryList[index];
                                  return buildCategoryItem(item, index);
                                },
                              ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    loader
                        ? Stack(
                          children: [
                            Container(
                              color: Design.getBackgroundColor(context),
                            ),
                            Center(
                              child: Image.asset(
                                'assets/Bird_Full_Eye_Blinking.gif',
                                width: 100,
                                height: 100,
                              ),
                            ),
                          ],
                        )
                        : canViewVenue == false
                        ? Center(
                          child: Text(
                            "You not have Permission to View Venues",
                            style: TextStyle(
                              fontSize: Design.font20,
                              color: Design.getTextColor(
                                context,
                              ).withOpacity(0.7),
                            ),
                          ),
                        )
                        : allData.isEmpty
                        ? Center(
                          child: Text(
                            'No Venues Found in ${categoryList.isNotEmpty ? categoryList[cardPosition]['name'] : 'Selected Category'}',
                            style: TextStyle(
                              fontSize: Design.font20,
                              color: Design.getTextColor(
                                context,
                              ).withOpacity(0.7),
                            ),
                          ),
                        )
                        : Column(
                          children: [
                            Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(
                                left: 16,
                                top: 20,
                                bottom: 10,
                              ),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Venues in ',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Design.getTextColor(context),
                                      ),
                                    ),
                                    TextSpan(
                                      text: categoryList[cardPosition]['name'],
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Design.primaryColorOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.only(
                                  left: 8,
                                  right: 8,
                                  top: 8,
                                  bottom:
                                      90, // Add bottom padding to prevent overflow
                                ),
                                itemCount: allData.length,
                                itemBuilder: (context, index) {
                                  final item = allData[index];
                                  return Column(
                                    children: [
                                      buildVenueItem(item),
                                      const SizedBox(height: 12),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
              ),
            ],
          ),
          if (dialogAlert)
            Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: Design.getBackgroundColor(context).withOpacity(0.9),
                  ),
                ),
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Design.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Design.getBorderColor(context)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confirm Deletion',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Design.getTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Are you sure you want to remove venue?',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: Design.font15,
                            fontWeight: FontWeight.w500,
                            color: Design.getTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    () => setState(() => dialogAlert = false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Design.getTextColor(
                                    context,
                                  ).withOpacity(0.7),
                                  side: BorderSide(
                                    color: Design.getBorderColor(context),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Design.getTextColor(context),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: removeVenueBtn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Design.primaryColorOrange,
                                  foregroundColor: Design.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                ),
                                child: Text(
                                  'OK',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Design.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    return Platform.isAndroid
        ? SafeArea(top: false, child: scaffold)
        : scaffold;
  }
}
