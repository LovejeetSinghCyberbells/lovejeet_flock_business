import 'dart:convert';
import 'dart:io';
import 'package:flock/custom_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  bool loader = false;
  List<dynamic> historyData = [];
  List<dynamic> checkInData = [];
  List<dynamic> offerRedemptionData = [];
  List<String> venueNames = [];
  String? selectedVenue;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    checkAuthentication();
    _initializePermissions();
  }

  /* --------- permissions section started -----*/
  List<Map<String, dynamic>> permissions = [];
  bool canAddVenue = false;
  bool canAddOffer = false;
  bool canViewCheckIns = false;

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

        return;
      }
      canAddVenue = hasPermissionToUser('Add venue');
      canAddOffer = hasPermissionToUser('Add offer');
      canViewCheckIns = hasPermissionToUser('List checkin-history');

      if (canViewCheckIns) print("✅ User can view check-ins.");
      if (canAddVenue) print("✅ User can add venues.");
      if (canAddOffer) print("✅ User can add offer.");

      if (!canAddVenue && !canAddOffer && !canViewCheckIns) {
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
    _tabController.dispose();
    super.dispose();
  }

  Future<void> checkAuthentication() async {
    final token = await _getToken();
    if (token.isEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      _fetchHistory();
    }
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? '';
  }

  Future<void> _fetchHistory() async {
    setState(() => loader = true);
    try {
      final token = await _getToken();
      if (token.isEmpty) throw Exception('No authentication token');

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      final response = await http
          .get(
            Uri.parse('https://api.getflock.io/api/vendor/transactions'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
      print("Response from fetch history : ${response.body} ");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final allTransactions = data['data'] ?? [];

        // Sort all transactions by date in descending order
        allTransactions.sort((a, b) {
          final dateAStr = a['datetime'];
          final dateBStr = b['datetime'];

          if (dateAStr == null || dateBStr == null) return 0;

          final dateA = DateFormat('MMMM-dd-yyyy hh:mm a').parse(dateAStr);
          final dateB = DateFormat('MMMM-dd-yyyy hh:mm a').parse(dateBStr);
          return dateB.compareTo(dateA); // Descending order
        });

        // Extract unique venue names for filtering
        final Set<String> uniqueVenueNames = {};
        for (var transaction in allTransactions) {
          final venueName = transaction['venue_name'];
          if (venueName != null && venueName.toString().isNotEmpty) {
            uniqueVenueNames.add(venueName.toString());
          }
        }

        // Split data by transaction title
        final checkIns = [];
        final redemptions = [];

        for (var transaction in allTransactions) {
          if (transaction['title'] == 'Check-In') {
            checkIns.add(transaction);
          } else {
            redemptions.add(
              transaction,
            ); // Includes Offer Redeemed and Offer Refunded
          }
        }

        setState(() {
          historyData = allTransactions;
          checkInData = checkIns;
          offerRedemptionData = redemptions;
          venueNames = uniqueVenueNames.toList()..sort();
          loader = false;
        });
      } else {
        throw Exception(
          'API Error ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      setState(() => loader = false);
      Fluttertoast.showToast(msg: 'Failed to load history: $e');
    }
  }

  // Filter displayed transactions based on venue selection
  List<dynamic> _getFilteredData(List<dynamic> data) {
    if (selectedVenue == null) {
      return data;
    }
    return data.where((item) => item['venue_name'] == selectedVenue).toList();
  }

  /// ----------  ITEM UI  ----------
  Widget _buildHistoryItem(Map<String, dynamic> item) {
    // Parse & format timestamp
    final inputFormat = DateFormat('MMMM-dd-yyyy hh:mm a');
    DateTime? timestamp;
    try {
      if (item['datetime'] != null) {
        timestamp = inputFormat.parse(item['datetime']);
      }
    } catch (e) {
      timestamp = null;
    }

    final formattedTime =
        timestamp != null
            ? DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp)
            : 'Unknown time';

    // Points sign & colour
    final featherPoints = item['feather_points'] as int? ?? 0;
    final venuePoints = item['venue_points'] as int? ?? 0;

    final bool isCheckIn = item['title'] == 'Check-In';
    final bool isOfferRedeemed = item['title'] == 'Offer Refunded';

    // Determine points text based on transaction type
    final featherPointsText =
        isCheckIn
            ? '- $featherPoints fts'
            : (isOfferRedeemed
                ? '- $featherPoints fts'
                : '+ $featherPoints fts');
    final venuePointsText =
        isCheckIn
            ? '- $venuePoints pts'
            : (isOfferRedeemed ? '- $venuePoints pts' : '+ $venuePoints pts');

    // Set points color based on transaction type
    final pointsColor =
        isCheckIn || isOfferRedeemed
            ? Colors.red.shade700
            : Colors.green.shade700;

    final IconData transactionIcon =
        isCheckIn ? Icons.login_rounded : Icons.redeem_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transaction type icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              transactionIcon,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Transaction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? (isCheckIn ? 'Check-In' : 'Offer Redeemed'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // Conditionally show offer name
                if (item['offer_name'] != null &&
                    item['offer_name'].toString().trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      item['offer_name'],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),

                // Venue name
                Row(
                  children: [
                    Icon(
                      Icons.store_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item['venue_name'] ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),

                // Date and time
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formattedTime,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),

                // Points display
                if (featherPoints > 0 || venuePoints > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (featherPoints > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: pointsColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              featherPointsText,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: pointsColor,
                              ),
                            ),
                          ),
                        if (venuePoints > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: pointsColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              venuePointsText,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: pointsColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ----------  PAGE UI  ----------
  @override
  Widget build(BuildContext context) {
    final filteredCheckInData = _getFilteredData(checkInData);
    final filteredOfferRedemptionData = _getFilteredData(offerRedemptionData);

    final scaffold = CustomScaffold(
      canAddOffer: canAddOffer,
      canAddVenue: canAddVenue,
      currentIndex: 2, // History tab
      body: SafeArea(
        child: Column(
          children: [
            // ---------- HEADER ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        'assets/back_updated.png',
                        height: 34,
                        width: 34,
                        fit: BoxFit.contain,
                        // color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Transaction History',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ---------- TABS ----------
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.onPrimary,
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.7),
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                unselectedLabelStyle: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.primary,
                ),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    height: 56,
                    iconMargin: const EdgeInsets.only(bottom: 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Check-ins',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    height: 56,
                    iconMargin: const EdgeInsets.only(bottom: 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.redeem_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Redemptions',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---------- VENUE FILTER ----------
            if (venueNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: GestureDetector(
                  onTap: () async {
                    final selected = await showDialog<String>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          title: Text(
                            'Select Venue',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                ListTile(
                                  title: Text(
                                    'All venues',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  onTap: () => Navigator.pop(context, null),
                                ),
                                ...venueNames.map((String venue) {
                                  return ListTile(
                                    title: Text(
                                      venue,
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                    ),
                                    onTap: () => Navigator.pop(context, venue),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                    if (selected != null || selectedVenue != null) {
                      setState(() {
                        selectedVenue = selected;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedVenue ?? 'All Venues',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontSize: 16,
                            color:
                                selectedVenue == null
                                    ? Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.5)
                                    : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Theme.of(context).iconTheme.color,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ---------- LIST CONTENT ----------
            Expanded(
              child:
                  loader
                      ? Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.14),
                        child: Center(
                          child: Image.asset(
                            'assets/Bird_Full_Eye_Blinking.gif',
                            width: 100,
                            height: 100,
                          ),
                        ),
                      )
                      : TabBarView(
                        controller: _tabController,
                        children: [
                          // Check-ins tab
                          canViewCheckIns == false
                              ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: Text(
                                    'You do not have Permission to access Check-Ins.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                              : filteredCheckInData.isEmpty
                              ? _buildEmptyState('No check-ins found')
                              : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                itemCount: filteredCheckInData.length,
                                itemBuilder:
                                    (context, index) => _buildHistoryItem(
                                      filteredCheckInData[index],
                                    ),
                              ),

                          // Offer Redemptions tab
                          filteredOfferRedemptionData.isEmpty
                              ? _buildEmptyState('No redemptions found')
                              : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                itemCount: filteredOfferRedemptionData.length,
                                itemBuilder:
                                    (context, index) => _buildHistoryItem(
                                      filteredOfferRedemptionData[index],
                                    ),
                              ),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
    return Platform.isAndroid ? SafeArea(child: scaffold) : scaffold;
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          if (selectedVenue != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    selectedVenue = null;
                  });
                },
                icon: Icon(
                  Icons.filter_alt_off,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(
                  'Clear filter',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
