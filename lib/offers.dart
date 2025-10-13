import 'dart:convert';
import 'package:flock/constants.dart';
import 'package:flock/offer_details.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flock/app_colors.dart'; // Import AppColors for primary color

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  bool isLoading = true;
  String errorMessage = '';
  List<dynamic> offersList = [];

  @override
  void initState() {
    super.initState();
    fetchOffers();
    _initializePermissions();
  }

  /* --------- permissions section started -----*/
  List<Map<String, dynamic>> permissions = [];
  bool canRemoveOffer = false;

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
        canRemoveOffer = true;

        return;
      }
      canRemoveOffer = hasPermissionToUser('Remove offer');

      if (canRemoveOffer) print("✅ User can Remove offer.");

      if (!canRemoveOffer) {
        print("❌ User has no permission to remove offer.");
      }
    });
  }

  Future<void> _initializePermissions() async {
    await fetchPermissions();
    checkPermission();
  }

  /* --------- permissions section endede -----*/

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> fetchOffers() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    String? token = await getToken();
    if (token == null || token.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final url = Uri.parse('https://api.getflock.io/api/vendor/offers');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          setState(() {
            offersList = List.from(data['data']);
          });
        } else {
          setState(() {
            errorMessage = data['message'] ?? 'No offers found.';
          });
        }
      } else {
        setState(() {
          errorMessage =
              'Error ${response.statusCode}: Unable to fetch offers.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: No internet connection';
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> removeOffer(int offerId) async {
    String? token = await getToken();
    if (token == null || token.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final url = Uri.parse('https://api.getflock.io/api/vendor/offers/$offerId');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          offersList.removeWhere((offer) => offer['id'] == offerId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Offer deleted successfully.',
                style: Theme.of(context).snackBarTheme.contentTextStyle,
              ),
              backgroundColor: Colors.green,
            ),
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to remove offer. Code: ${response.statusCode}',
              style: Theme.of(context).snackBarTheme.contentTextStyle,
            ),
            backgroundColor: Theme.of(context).snackBarTheme.backgroundColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network error: $e',
            style: Theme.of(context).snackBarTheme.contentTextStyle,
          ),
          backgroundColor: Theme.of(context).snackBarTheme.backgroundColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppConstants.customAppBar(context: context, title: 'Offers'),
      body:
          isLoading
              ? Stack(
                children: [
                  Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.14),
                  ),
                  Container(
                    color: Theme.of(
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
              )
              : errorMessage.isNotEmpty
              ? Center(
                child: Text(
                  errorMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
              : offersList.isEmpty
              ? Center(
                child: Text(
                  'No offers found.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  itemCount: offersList.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    // childAspectRatio: 0.80,
                    mainAxisExtent: MediaQuery.of(context).size.height * 0.3,
                  ),
                  itemBuilder: (context, index) {
                    final offer = offersList[index];
                    final int offerId = offer['id'];
                    final String discount = offer['name']?.toString() ?? '0';
                    final String desc =
                        (offer['description']?.toString().trim().isNotEmpty ??
                                false)
                            ? offer['description'].toString()
                            : 'No Description';
                    final String venueName =
                        offer['venue']?['name']?.toString() ?? 'No Venue';
                    final String imageUrl =
                        (offer['images'] is List &&
                                offer['images'].isNotEmpty &&
                                offer['images'][0]['medium_image'] != null)
                            ? offer['images'][0]['medium_image']
                            : '';
                    bool isExpired = offer['expire_at'] != null;

                    return Container(
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Design.darkSurface
                                : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black.withOpacity(0.3)
                                    : Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.2),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Offer Image
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child:
                                    imageUrl.isNotEmpty
                                        ? Image.network(
                                          imageUrl,
                                          height: 100,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return Container(
                                              height: 100,
                                              width: double.infinity,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.1),
                                              child: Center(
                                                child: Image.asset(
                                                  'assets/Bird_Full_Eye_Blinking.gif',
                                                  width: 50,
                                                  height: 50,
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              height: 100,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.1),
                                              child: Icon(
                                                Icons.broken_image,
                                                size: 40,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                              ),
                                            );
                                          },
                                        )
                                        : Container(
                                          height: 100,
                                          width: double.infinity,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.1),
                                          child: Icon(
                                            Icons.image_not_supported,
                                            size: 30,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                              ),
                              // Offer details
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      discount,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: double.infinity,
                                      child: Text(
                                        desc,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.copyWith(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Image.asset(
                                          'assets/orange_hotel.png',
                                          width: 14,
                                          height: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            venueName,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Spacer to push buttons to the bottom
                              const Spacer(),
                              // Bottom button row
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      canRemoveOffer == false
                                          ? MainAxisAlignment.center
                                          : MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Delete button
                                    canRemoveOffer == false
                                        ? Container()
                                        : Container(
                                          decoration: const BoxDecoration(),
                                          child: SizedBox(
                                            height: 30,
                                            width: 66,
                                            child: cardWrapper(
                                              borderRadius: 5,
                                              elevation:
                                                  Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? 4
                                                      : 2,
                                              color:
                                                  Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? const Color(0xFFD32F2F)
                                                      : const Color(0xFFE53935),
                                              child: InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (
                                                      BuildContext context,
                                                    ) {
                                                      return AlertDialog(
                                                        backgroundColor:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .surface,
                                                        title: Text(
                                                          'Confirm Deletion',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleMedium,
                                                        ),
                                                        content: Text(
                                                          'Are you sure you want to delete this offer?',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyMedium,
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.of(
                                                                context,
                                                              ).pop();
                                                            },
                                                            child: Text(
                                                              'CANCEL',
                                                              style: Theme.of(
                                                                    context,
                                                                  )
                                                                  .textButtonTheme
                                                                  .style
                                                                  ?.textStyle
                                                                  ?.resolve({})!
                                                                  .copyWith(
                                                                    color: Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .onSurface
                                                                        .withOpacity(
                                                                          0.6,
                                                                        ),
                                                                  ),
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.of(
                                                                context,
                                                              ).pop();
                                                              removeOffer(
                                                                offerId,
                                                              );
                                                            },
                                                            child: Text(
                                                              'OK',
                                                              style: Theme.of(
                                                                    context,
                                                                  )
                                                                  .textButtonTheme
                                                                  .style
                                                                  ?.textStyle
                                                                  ?.resolve({})!
                                                                  .copyWith(
                                                                    color:
                                                                        AppColors
                                                                            .primary,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                },
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                      ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.delete,
                                                        size: 14,
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .onError,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Delete',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              fontSize: 11,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onError,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    // See Details button
                                    SizedBox(
                                      height: 30,
                                      width: 66,
                                      child: cardWrapper(
                                        borderRadius: 5,
                                        elevation:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? 4
                                                : 2,
                                        color:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? AppColors.primary
                                                : Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                        child: InkWell(
                                          onTap: () {
                                            print(
                                              'Details button tapped for offer ID: $offerId',
                                            );
                                            try {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) => OfferDetails(
                                                        allDetail: offer,
                                                      ),
                                                ),
                                              );
                                            } catch (e) {
                                              print('Navigation error: $e');
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to navigate to details: $e',
                                                    style:
                                                        Theme.of(context)
                                                            .snackBarTheme
                                                            .contentTextStyle,
                                                  ),
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .snackBarTheme
                                                          .backgroundColor,
                                                ),
                                              );
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Image.asset(
                                                  'assets/view.png',
                                                  height: 14,
                                                  width: 12,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.onPrimary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Details',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontSize: 11,
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .onPrimary,
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
                              ),
                            ],
                          ),
                          // Expired text in top left corner
                          if (isExpired)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                color: Theme.of(
                                  context,
                                ).colorScheme.error.withOpacity(0.8),
                                child: Text(
                                  'Expired',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onError,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
    );
  }
}

// Placeholder for cardWrapper
Widget cardWrapper({
  required double borderRadius,
  required double elevation,
  required Color color,
  required Widget child,
}) {
  return Material(
    elevation: elevation,
    borderRadius: BorderRadius.circular(borderRadius),
    color: color,
    child: child,
  );
}

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
  static const Color darkBackground = Color(
    0xFF1A1A1A,
  ); // Professional dark black
  static const Color darkSurface = Color(
    0xFF242424,
  ); // Slightly lighter surface
  static const Color darkBorder = Color(0xFF2C2C2C); // Subtle border color
  static const Color darkCard = Color(0xFF2A2A2A); // Card background
  static const Color darkDivider = Color(0xFF383838); // Divider color
  static const Color darkInput = Color(0xFF333333); // Input field background

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
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(
          0.87,
        ) // Slightly dimmed white for better contrast
        : black;
  }

  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : Colors.grey.withOpacity(0.3);
  }
}
