import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flock/app_colors.dart';

// Add Design class for dark mode colors
class Design {
  static const Color darkBackground = Color(
    0xFF1A1A1A,
  ); // Professional dark black
  static const Color darkSurface = Color(
    0xFF242424,
  ); // Slightly lighter surface
  static const Color darkCard = Color(0xFF2A2A2A); // Card background
  static const Color darkBorder = Color(0xFF2C2C2C); // Subtle border color
  static const Color darkDivider = Color(0xFF383838); // Divider color

  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : Theme.of(context).scaffoldBackgroundColor;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : Theme.of(context).colorScheme.surface;
  }
}

class OfferDetails extends StatefulWidget {
  final Map<String, dynamic> allDetail;

  const OfferDetails({super.key, required this.allDetail});

  @override
  State<OfferDetails> createState() => _OfferDetailsState();
}

class _OfferDetailsState extends State<OfferDetails> {
  bool isLoading = false;
  String errorMessage = '';

  // Offer detail variables
  late int offerId;
  late int? venueId;
  late String venueName;
  late String offerName;
  late String imageUrl;
  late String description;
  late int redeemed_count;
  late String? expireAt;
  late String discount;

  // Redeemed people list
  List<dynamic> redeemedPeopleList = [];

  // QR Scanner controller
  late MobileScannerController _scannerController;

  @override
  void initState() {
    super.initState();
    final detail = widget.allDetail;
    print('Offer details received: $detail'); // Debug log

    offerId = detail['id'] ?? 0;
    venueId = detail['venue_id'] ?? detail['venue']?['id'];
    venueName = detail['venue']?['name'] ?? 'No Venue';
    offerName = detail['name'] ?? 'No Title';

    // Handle both image formats
    final images = detail['images'] as List<dynamic>?;
    if (images != null && images.isNotEmpty) {
      imageUrl = images[0]['medium_image'] ?? images[0]['image'] ?? '';
    } else {
      imageUrl = '';
    }

    description = detail['description'] ?? 'No description available';
    redeemed_count = detail['people'] ?? detail['redeemed_count'] ?? 0;
    expireAt = detail['expire_at']?.toString();
    discount = detail['discount']?.toString() ?? '0';

    print('Parsed offer details:'); // Debug log
    print('ID: $offerId');
    print('Venue: $venueName');
    print('Name: $offerName');
    print('Image URL: $imageUrl');
    print('Description: $description');
    print('Redeemed count: $redeemed_count');
    print('Expire at: $expireAt');
    print('Discount: $discount');

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    fetchRedeemedPeople();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  void _setLoading(bool loading) {
    setState(() {
      isLoading = loading;
      errorMessage = '';
    });
  }

  Future<void> fetchRedeemedPeople() async {
    _setLoading(true);
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Authentication failed. Please login again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      );
      return;
    }

    try {
      final url = Uri.parse(
        'https://api.getflock.io/api/vendor/offers/$offerId/redeemed-count',
      );
      final request = http.MultipartRequest('GET', url);
      request.headers['Authorization'] = 'Bearer $token';

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          setState(() {
            redeemed_count = data['data']['count'];
          });
        } else {
          setState(() {
            errorMessage =
                data['message'] ?? 'Failed to fetch redeemed people.';
          });
        }
      } else {
        setState(() {
          errorMessage =
              'Failed to fetch redeemed people. Code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
      });
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeOffer() async {
    Navigator.pop(context);
    _setLoading(true);
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Authentication failed. Please login again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      );
      return;
    }
    try {
      final url = Uri.parse(
        'https://api.getflock.io/api/vendor/offers/$offerId',
      );
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'Offer removed successfully!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() {
          errorMessage = 'Failed to remove offer. Code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
      });
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleOfferStatus() async {
    _setLoading(true);
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Authentication failed. Please login again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      );
      return;
    }
    try {
      final url = Uri.parse(
        'https://api.getflock.io/api/vendor/offers/$offerId/expire-toggle',
      );
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            expireAt = data['data']['expire_at']?.toString();
          });

          widget.allDetail['expire_at'] = expireAt;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                expireAt != null
                    ? 'Offer Ended Successfully!'
                    : 'Offer Reactivated Successfully!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          setState(() {
            errorMessage = data['message'] ?? 'Failed to toggle offer status.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        setState(() {
          errorMessage =
              'Failed to toggle offer status. Code: ${response.statusCode}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> scanQR() async {
    if (expireAt != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Cannot scan QR code: Offer is expired.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      );
      return;
    }

    try {
      await _scannerController.start();
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: AppBar(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  title: Text(
                    'Scan QR Code',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                body: Stack(
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) async {
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final qrCode = barcodes.first.rawValue ?? '';
                          await _scannerController.stop();
                          if (!mounted) return;
                          Navigator.pop(context);
                          await _verifyQRCode(qrCode);
                        }
                      },
                    ),
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ).then((_) async {
        await _scannerController.stop();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Error starting scanner: $e',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _verifyQRCode(String qrCode) async {
    _setLoading(true);
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Authentication failed. Please login again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      );
      return;
    }

    if (expireAt != null) {
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Cannot verify QR code: Offer is expired.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      );
      return;
    }

    if (qrCode.isEmpty) {
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Invalid QR code: Empty data.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      );
      return;
    }

    Map<String, dynamic> decodedData;
    try {
      decodedData = jsonDecode(qrCode);
    } catch (e) {
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Invalid QR code.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      );
      return;
    }

    final redeemId = decodedData['redeem_id'];
    if (redeemId == null) {
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Invalid QR code.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      );
      return;
    }

    int? parsedRedeemId;
    try {
      parsedRedeemId = int.parse(redeemId.toString());
    } catch (e) {
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Invalid QR code.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      );
      return;
    }

    try {
      final url = Uri.parse(
        'https://api.getflock.io/api/vendor/redeemed-offers/$parsedRedeemId/verify?venue_id=$venueId',
      );
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? 'Offer verified successfully!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          await fetchRedeemedPeople();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? 'Verification failed.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification error: ${response.statusCode} - ${response.body}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network error: $e',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setLoading(false);
    }
  }

  void showRedeemedPeopleDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor:
              Theme.of(context).brightness == Brightness.dark
                  ? Design.darkCard
                  : Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Design.darkBorder
                      : Colors.grey.withOpacity(0.2),
            ),
          ),
          title: Text(
            'Redeemed People List',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : null,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child:
                redeemedPeopleList.isEmpty
                    ? Center(
                      child: Text(
                        'No data found.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                    : ListView.builder(
                      itemCount: redeemedPeopleList.length,
                      itemBuilder: (context, index) {
                        final person = redeemedPeopleList[index];
                        final username = person['username'] ?? 'Unknown';
                        final image = person['images'];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                image != null
                                    ? NetworkImage(image)
                                    : const AssetImage('assets/placeholder.png')
                                        as ImageProvider,
                          ),
                          title: Text(
                            username,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        );
                      },
                    ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Done',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void showRemoveDialogFunc() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor:
                Theme.of(context).brightness == Brightness.dark
                    ? Design.darkCard
                    : Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Design.darkBorder
                        : Colors.grey.withOpacity(0.2),
              ),
            ),
            title: Text(
              'Delete Offer',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : null,
              ),
            ),
            content: Text(
              'Are you sure you want to remove this offer?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'CANCEL',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  removeOffer();
                },
                child: Text(
                  'OK',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void showToggleOfferDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor:
                Theme.of(context).brightness == Brightness.dark
                    ? Design.darkCard
                    : Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Design.darkBorder
                        : Colors.grey.withOpacity(0.2),
              ),
            ),
            title: Text(
              expireAt != null ? 'Reactivate Offer' : 'End Offer',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : null,
              ),
            ),
            content: Text(
              expireAt != null
                  ? 'Are you sure you want to bring this offer back?'
                  : 'Are you sure you want to end this offer?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'CANCEL',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  toggleOfferStatus();
                },
                child: Text(
                  'OK',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isExpired = expireAt != null;

    return Stack(
      children: [
        Scaffold(
          backgroundColor:
              Theme.of(context).brightness == Brightness.dark
                  ? Design.darkBackground
                  : Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor:
                Theme.of(context).brightness == Brightness.dark
                    ? Design.darkSurface
                    : Theme.of(context).colorScheme.surface,
            title: Text(
              'Offer Detail',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : null,
              ),
            ),
            leading: IconButton(
              icon: Image.asset(
                'assets/back_updated.png',
                height: 40,
                width: 34,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.qr_code,
                  color:
                      isExpired
                          ? Theme.of(context).iconTheme.color?.withOpacity(0.5)
                          : Theme.of(context).iconTheme.color,
                ),
                onPressed: isExpired ? null : scanQR,
                tooltip: isExpired ? 'Offer Expired' : 'Scan QR Code',
              ),
            ],
          ),
          body:
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage.isNotEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              errorMessage = '';
                            });
                            fetchRedeemedPeople();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                  : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl.isNotEmpty)
                          Align(
                            alignment: AlignmentGeometry.center,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  ColorFiltered(
                                    colorFilter:
                                        isExpired
                                            ? const ColorFilter.mode(
                                              Colors.grey,
                                              BlendMode.saturation,
                                            )
                                            : const ColorFilter.mode(
                                              Colors.transparent,
                                              BlendMode.dst,
                                            ),
                                    child: Image.network(
                                      imageUrl,
                                      height:
                                          MediaQuery.of(context).size.width *
                                          0.3,
                                      fit: BoxFit.fitWidth,
                                      filterQuality: FilterQuality.high,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        print(
                                          'Image error: $error',
                                        ); // Debug log
                                        return Container(
                                          height: 200,
                                          color:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Colors.black.withOpacity(
                                                    0.3,
                                                  )
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.2),
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 50,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white.withOpacity(
                                                      0.7,
                                                    )
                                                    : Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (isExpired)
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Offer Expired',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          offerName,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          textAlign: TextAlign.justify,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Image.asset(
                                      'assets/orange_hotel.png',
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                      width: 16,
                                      height: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Offered by:',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  venueName,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Redeemed',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  redeemed_count.toString(),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: showRemoveDialogFunc,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? 4
                                          : 2,
                                ),
                                child: Text(
                                  'Delete Offer',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelLarge?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onError,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: showToggleOfferDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isExpired
                                          ? Colors.green
                                          : AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? 4
                                          : 2,
                                ),
                                child: Text(
                                  isExpired ? 'Bring Offer Back' : 'End Offer',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelLarge?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
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
        // if (isLoading)
        //   Container(
        //     color: Colors.black.withOpacity(0.3),
        //     child: const Center(child: CircularProgressIndicator()),
        //   ),
      ],
    );
  }
}
