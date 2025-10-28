import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

class DeepLinkService {
  // Generate a deep link that automatically redirects to app store if app not installed
  static Future<String> generateCheckInLink(String venueId) async {
    final lp = BranchLinkProperties();

    // Set control parameters
    lp.addControlParam('venue_id', venueId);
    lp.addControlParam('\$deeplink_path', 'checkin/$venueId');

    // Set fallback URLs for when app is not installed
    lp.addControlParam(
      '\$ios_url',
      'https://apps.apple.com/app/flock-loyalty/id123456789',
    ); // Replace with your actual App Store ID
    lp.addControlParam(
      '\$android_url',
      'https://play.google.com/store/apps/details?id=com.example.flock',
    ); // Replace with your actual package name
    lp.addControlParam('\$desktop_url', 'https://getflock.io/download');

    // Force redirect to app store if app not installed (no prompts)
    lp.addControlParam('\$ios_redirect_mode', '2'); // 2 = force redirect
    lp.addControlParam('\$android_redirect_mode', '2'); // 2 = force redirect
    lp.addControlParam('\$desktop_redirect_mode', '2'); // 2 = force redirect
    lp.addControlParam('\$one_time_use', 'true'); // Prevent link reuse
    lp.addControlParam(
      '\$always_deeplink',
      'true',
    ); // Always try to deep link first

    final buo = BranchUniversalObject(
      canonicalIdentifier: 'venue_checkin_$venueId',
      title: 'Venue Check-in',
      contentDescription: 'Check-in to venue',
      contentMetadata:
          BranchContentMetaData()..addCustomMetadata('venue_id', venueId),
    );
    final response = await FlutterBranchSdk.getShortUrl(
      buo: buo,
      linkProperties: lp,
    );
    return response.result ?? 'https://flockloyalty.app.link/checkin/$venueId';
  }

  // Generate QR code link with automatic app store fallback
  static Future<String> generateQRCodeLink(String venueId) async {
    final lp = BranchLinkProperties();

    // Set control parameters
    lp.addControlParam('venue_id', venueId);
    lp.addControlParam('type', 'qr_checkin');
    lp.addControlParam('\$deeplink_path', 'qr_checkin/$venueId');

    // Set fallback URLs for when app is not installed
    lp.addControlParam(
      '\$ios_url',
      'https://apps.apple.com/app/flock-loyalty/id123456789',
    ); // Replace with your actual App Store ID
    lp.addControlParam(
      '\$android_url',
      'https://play.google.com/store/apps/details?id=com.example.flock',
    ); // Replace with your actual package name
    lp.addControlParam('\$desktop_url', 'https://getflock.io/download');

    // Force redirect to app store if app not installed (no prompts)
    lp.addControlParam('\$ios_redirect_mode', '2'); // 2 = force redirect
    lp.addControlParam('\$android_redirect_mode', '2'); // 2 = force redirect
    lp.addControlParam('\$desktop_redirect_mode', '2'); // 2 = force redirect
    lp.addControlParam('\$one_time_use', 'true'); // Prevent link reuse
    lp.addControlParam(
      '\$always_deeplink',
      'true',
    ); // Always try to deep link first

    final buo = BranchUniversalObject(
      canonicalIdentifier: 'venue_qr_checkin_$venueId',
      title: 'Venue QR Check-in',
      contentDescription: 'QR check-in to venue',
      contentMetadata:
          BranchContentMetaData()..addCustomMetadata('venue_id', venueId),
    );
    final response = await FlutterBranchSdk.getShortUrl(
      buo: buo,
      linkProperties: lp,
    );
    return response.result ??
        'https://flockloyalty.app.link/qr_checkin/$venueId';
  }

  // Generate a link with custom fallback URLs
  static Future<String> generateCustomLink({
    required String venueId,
    required String type,
    String? customPath,
    String? iosAppStoreUrl,
    String? androidPlayStoreUrl,
    String? webFallbackUrl,
  }) async {
    final lp = BranchLinkProperties();

    // Set control parameters
    lp.addControlParam('venue_id', venueId);
    lp.addControlParam('type', type);
    lp.addControlParam('\$deeplink_path', customPath ?? '$type/$venueId');

    // Set fallback URLs for when app is not installed
    lp.addControlParam(
      '\$ios_url',
      iosAppStoreUrl ?? 'https://apps.apple.com/app/flock-loyalty/id123456789',
    );
    lp.addControlParam(
      '\$android_url',
      androidPlayStoreUrl ??
          'https://play.google.com/store/apps/details?id=com.example.flock',
    );
    lp.addControlParam(
      '\$desktop_url',
      webFallbackUrl ?? 'https://getflock.io/download',
    );

    // Force redirect to app store if app not installed (no prompts)
    lp.addControlParam('\$ios_redirect_mode', '2'); // 2 = force redirect
    lp.addControlParam('\$android_redirect_mode', '2'); // 2 = force redirect
    lp.addControlParam('\$desktop_redirect_mode', '2'); // 2 = force redirect
    lp.addControlParam('\$one_time_use', 'true'); // Prevent link reuse
    lp.addControlParam(
      '\$always_deeplink',
      'true',
    ); // Always try to deep link first

    final buo = BranchUniversalObject(
      canonicalIdentifier: 'venue_${type}_$venueId',
      title: 'Venue $type',
      contentDescription: '$type for venue',
      contentMetadata:
          BranchContentMetaData()..addCustomMetadata('venue_id', venueId),
    );
    final response = await FlutterBranchSdk.getShortUrl(
      buo: buo,
      linkProperties: lp,
    );
    return response.result ?? 'https://flockloyalty.app.link/$type/$venueId';
  }

  // Handle incoming deep links
  static void handleDeepLink(dynamic data) {
    if (data != null && data is Map) {
      final venueId = data['venue_id'];
      final type = data['type'];

      // Handle different types of deep links
      switch (type) {
        case 'qr_checkin':
          // Handle QR code check-in
          print('QR Check-in for venue: $venueId');
          break;
        case 'checkin':
          // Handle regular check-in
          print('Check-in for venue: $venueId');
          break;
        default:
          print('Unknown deep link type: $type');
      }
    }
  }

  // Initialize Branch SDK with your keys
  static Future<void> initializeBranch() async {
    await FlutterBranchSdk.init(enableLogging: true);
  }
}
