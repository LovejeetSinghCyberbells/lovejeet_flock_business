import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

class Design {
  static const Color primaryColorOrange = Color.fromRGBO(255, 152, 0, 1);
  static const Color black = Colors.black;
  static const Color white = Colors.white;
  static const Color lightPurple = Color(0xFFF0F0F5);
  static const Color blue = Colors.blue;
  static const Color errorRed = Colors.red;

  // Dark mode colors
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF242424);
  static const Color darkBorder = Color(0xFF3E3E3E);

  // Theme-aware colors
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

/* ───────────────────────────── SCREEN ───────────────────────────── */

class AddOfferScreen extends StatefulWidget {
  const AddOfferScreen({super.key});
  @override
  State<AddOfferScreen> createState() => _AddOfferScreenState();
}

class _AddOfferScreenState extends State<AddOfferScreen> {
  /* ---------------- controllers & form ---------------- */
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venuePointsController = TextEditingController();
  final _appPointsController = TextEditingController();
  final _redemptionLimitController = TextEditingController();
  final _scrollController = ScrollController();
  bool _venueValidationError = false;
  bool _imageValidationError = false;
  bool _redeemTypeValidationError = false;
  bool _showValidationMessages = false;
  bool _isPointOrFeatherError = false;
  String? _addOfferError;

  /* ---------------- page state ---------------- */
  List<Map<String, dynamic>> _venues = [
    {'id': null, 'name': 'Select Venue'},
  ];
  Map<String, dynamic>? _selectedVenue;

  bool _useVenuePoints = false;
  bool _useAppPoints = false;

  XFile? _pickedImage;

  bool _isVenuesLoading = false;
  bool _isSubmitting = false;

  /* ───────────────────────── lifecycle ───────────────────────── */

  @override
  void initState() {
    super.initState();
    _selectedVenue = _venues.first;
    _fetchVenues();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).addListener(_onFocusChange);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _venuePointsController.dispose();
    _appPointsController.dispose();
    _redemptionLimitController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /* ───────────────────────── helpers ───────────────────────── */

  Future<String?> _getToken() async =>
      (await SharedPreferences.getInstance()).getString('access_token');

  Future<void> _fetchVenues() async {
    setState(() {
      _isVenuesLoading = true;
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('https://api.getflock.io/api/vendor/venues'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'success' && json['data'] != null) {
          final v =
              (json['data'] as List<dynamic>)
                  .map((e) => {'id': e['id'], 'name': e['name'] ?? 'Unnamed'})
                  .toList();
          _venues = [
            {'id': null, 'name': 'Select Venue'},
            ...v,
          ];
          _selectedVenue = _venues.first;
        }
      }
    } catch (e) {
      // Handle error silently
    }
    if (mounted) setState(() => _isVenuesLoading = false);
  }

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img != null) {
      // final compressed = await compressImage(img);
      setState(() {
        _pickedImage = img;
        _imageValidationError = false;
      });
    }
  }
  // Future<void> _pickImage() async {
  //   final img = await ImagePicker().pickImage(source: ImageSource.gallery);
  //   if (img != null) {
  //     // final compressed = await compressImage(img);
  //     if (compressed != null) {
  //       setState(() {
  //         _pickedImage = compressed;
  //         _imageValidationError = false;
  //       });
  //     } else {
  //       // Fallback: if compression fails, use original
  //       setState(() {
  //         _pickedImage = img;
  //         _imageValidationError = false;
  //       });
  //     }
  //   }
  // }

  void _onFocusChange() {
    if (FocusScope.of(context).hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // Future<XFile?> compressImage(XFile file) async {
  //   final extension = path.extension(file.path);
  //   final outPath = file.path.replaceAll(extension, '_compressed$extension');

  //   return await FlutterImageCompress.compressAndGetFile(
  //     file.path,
  //     outPath,
  //     quality: 100,
  //     format: CompressFormat.jpeg,
  //     minWidth: 0,
  //     minHeight: 0,
  //   );
  // }

  // Future<XFile?> compressImage(XFile file) async {
  //   final outPath = file.path.replaceAll('.jpg', '_compressed.jpg');

  //   return await FlutterImageCompress.compressAndGetFile(
  //     file.path,
  //     outPath,
  //     quality: 95,
  //     format: CompressFormat.jpeg,
  //     keepExif: true,
  //     autoCorrectionAngle: true,
  //     minWidth: 1920,
  //     minHeight: 1080,
  //   );
  // }

  /* ───────────────────────── submit ───────────────────────── */

  Future<void> _submitOffer() async {
    var venuePts = _venuePointsController.text.trim();
    var appPts = _appPointsController.text.trim();
    final name = _nameController.text.trim();
    final desc = _descriptionController.text.trim();
    final limitRaw = _redemptionLimitController.text.trim();
    setState(() {
      _isPointOrFeatherError = venuePts.isEmpty && appPts.isEmpty;
      _venueValidationError =
          _selectedVenue == null || _selectedVenue!['id'] == null;
      _imageValidationError = _pickedImage == null;
      _redeemTypeValidationError = !_useVenuePoints && !_useAppPoints;
      _showValidationMessages = true;
    });

    if (!_formKey.currentState!.validate() ||
        _venueValidationError ||
        _imageValidationError ||
        _redeemTypeValidationError ||
        _isPointOrFeatherError) {
      _scrollToError();
      return;
    }

    if (_useVenuePoints && appPts.isEmpty && venuePts.isNotEmpty) {
      setState(() {
        _useAppPoints = false;
      });
    } else if (_useAppPoints && appPts.isNotEmpty && venuePts.isEmpty) {
      setState(() {
        _useVenuePoints = false;
      });
    }

    /* redemption-limit → int */
    int redemptionLimit = -1;
    if (limitRaw.isNotEmpty) {
      redemptionLimit = int.tryParse(limitRaw) ?? -2;
      if (redemptionLimit < -1) {
        _scrollToError();
        return;
      }
    }

    /* guarantee numeric strings for disabled fields */
    if (!_useVenuePoints) venuePts = '0';
    if (!_useAppPoints) appPts = '0';

    setState(() => _isSubmitting = true);

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final url = 'https://api.getflock.io/api/vendor/offers';
    final uri = Uri.parse(url);
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['name'] = name;
    request.fields['description'] = desc;
    request.fields['venue_id'] = _selectedVenue!['id'].toString();
    request.fields['redeem_by'] =
        _useVenuePoints && _useAppPoints
            ? 'both'
            : _useVenuePoints
            ? 'venue_points'
            : 'feather_points';
    request.fields['venue_points'] = venuePts;
    request.fields['feather_points'] = appPts;
    request.fields['redemption_limit'] = redemptionLimit.toString();

    if (_pickedImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath('images[]', _pickedImage!.path),
      );
    }

    try {
      final response = await request.send();
      final responseString = await response.stream.bytesToString();

      final data = jsonDecode(responseString);
      print("Added Offer Data : $data");
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['status'] == 'success' ||
            (data['message'] ?? '').toString().toLowerCase().contains(
              'success',
            )) {
          if (mounted) _showSuccessDialog();
        }
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() => showDialog(
    context: context,
    builder:
        (_) => AlertDialog(
          backgroundColor: Design.getSurfaceColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            'Success',
            style: TextStyle(
              color: Design.getTextColor(context),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Offer added successfully!',
            style: TextStyle(color: Design.getTextColor(context), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: const Color.fromRGBO(255, 140, 16, 1),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
  );

  void _scrollToError() {
    final ctx = _formKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Design.getBackgroundColor(context),
    appBar: AppBar(
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Image.asset('assets/back_updated.png', height: 40, width: 34),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Add New Offer',
        style: TextStyle(
          color: Theme.of(context).textTheme.titleLarge!.color,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    ),
    resizeToAvoidBottomInset: false,
    body: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Title of Offer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Design.getTextColor(context),
                ),
              ),
              const SizedBox(height: 8), _buildTitleField(),

              // Container(
              //   decoration: BoxDecoration(
              //     color: Design.getSurfaceColor(context),
              //     borderRadius: BorderRadius.circular(10),
              //     border: Border.all(
              //       color:
              //           _showValidationMessages && _nameController.text.isEmpty
              //               ? Design.errorRed
              //               : Design.getBorderColor(context),
              //     ),
              //     boxShadow: [
              //       BoxShadow(
              //         color:
              //             Theme.of(context).brightness == Brightness.dark
              //                 ? Colors.black.withOpacity(0.3)
              //                 : Colors.black.withOpacity(0.1),
              //         spreadRadius: 1,
              //         blurRadius: 6,
              //         offset: const Offset(0, 3),
              //       ),
              //     ],
              //   ),
              //   child: TextFormField(
              //     controller: _nameController,
              //     style: TextStyle(
              //       color: Design.getTextColor(context),
              //       fontSize: 14,
              //     ),
              //     decoration: _inputDecoration('Title of Offer'),
              //     textInputAction: TextInputAction.next,
              //     validator: (v) => null,
              //     onChanged: (value) {
              //       setState(() {
              //         if (_showValidationMessages &&
              //             _nameController.text.isEmpty) {
              //           _showValidationMessages = false;
              //         }
              //       });
              //     },
              //   ),
              // ),
              if (_showValidationMessages && _nameController.text.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Please enter title.',
                    style: TextStyle(color: Design.errorRed, fontSize: 12),
                  ),
                ),
              SizedBox(
                height:
                    _showValidationMessages && _nameController.text.isEmpty
                        ? 8
                        : 16,
              ),
              Text(
                'Venue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Design.getTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              _buildVenueDropdown(),
              if (_venueValidationError)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Please select venue.',
                    style: TextStyle(color: Design.errorRed, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Redemption Requirements',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Design.getTextColor(context),
                ),
              ),
              _buildRedeemTypeRow(),
              if (_redeemTypeValidationError)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Select at least one redeem type.',
                    style: TextStyle(color: Design.errorRed, fontSize: 12),
                  ),
                ),
              if (_useVenuePoints || _useAppPoints) ...[
                _buildPointsInputs(),
                const SizedBox(height: 16),
              ],
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Design.getTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              _buildDescriptionField(),
              if (_showValidationMessages &&
                  _descriptionController.text.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Please enter the description.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              _buildRedemptionLimit(),
              if (_showValidationMessages &&
                  _redemptionLimitController.text.isNotEmpty &&
                  (int.tryParse(_redemptionLimitController.text) == null ||
                      int.parse(_redemptionLimitController.text) < -1))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Invalid redemption limit.',
                    style: TextStyle(color: Design.errorRed, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              _buildImagePicker(),
              if (_imageValidationError)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Please upload an image.',
                    style: TextStyle(color: Design.errorRed, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isSubmitting ? null : _submitOffer,
                child: Container(
                  alignment: Alignment.center,
                  height: 48,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Design.primaryColorOrange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      _isSubmitting
                          ? Image.asset(
                            'assets/Bird_Full_Eye_Blinking.gif',
                            width: 100,
                            height: 100,
                            alignment: AlignmentGeometry.center,
                          )
                          : Text(
                            'Save Offer',
                            style: TextStyle(
                              color: Design.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildVenueDropdown() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: () => _scrollToBottom(),
        child: Container(
          decoration: BoxDecoration(
            color: Design.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  _venueValidationError
                      ? Design.errorRed
                      : Design.getBorderColor(context),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child:
              _isVenuesLoading
                  ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Design.primaryColorOrange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Loading venues...',
                          style: TextStyle(
                            color: Design.getTextColor(
                              context,
                            ).withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                  : DropdownButtonHideUnderline(
                    child: ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButton<Map<String, dynamic>>(
                        value: _selectedVenue,
                        isExpanded: true,
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: Design.getTextColor(context).withOpacity(0.5),
                        ),
                        dropdownColor: Design.getSurfaceColor(context),
                        items:
                            _venues
                                .map(
                                  (v) => DropdownMenuItem<Map<String, dynamic>>(
                                    value: v,
                                    child: Text(
                                      v['name'] ?? 'Unnamed',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Design.getTextColor(context),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (v) => setState(() {
                              _selectedVenue = v;
                              _venueValidationError = false;
                              _scrollToBottom();
                            }),
                      ),
                    ),
                  ),
        ),
      ),
    ],
  );

  Widget _buildRedeemTypeRow() {
    Color label(bool enabled) =>
        enabled
            ? Design.getTextColor(context)
            : Design.getTextColor(context).withOpacity(0.5);

    final bool showError = _redeemTypeValidationError;
    final Color checkboxColor =
        showError ? Colors.red : Design.primaryColorOrange;

    return Wrap(
      spacing: 24,
      runSpacing: -15,
      children: [
        Transform.translate(
          offset: const Offset(-8, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                activeColor: checkboxColor,
                side: WidgetStateBorderSide.resolveWith(
                  (states) => BorderSide(color: checkboxColor, width: 2),
                ),
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                value: _useVenuePoints,
                onChanged: (value) {
                  setState(() {
                    _useVenuePoints = value ?? false;
                    _redeemTypeValidationError =
                        !_useVenuePoints && !_useAppPoints;
                  });
                },
              ),
              Text(
                'Venue Points',
                style: TextStyle(color: label(true), fontSize: 14),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(25, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                activeColor: checkboxColor,
                side: WidgetStateBorderSide.resolveWith(
                  (states) => BorderSide(color: checkboxColor, width: 2),
                ),
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                value: _useAppPoints,
                onChanged: (value) {
                  setState(() {
                    _useAppPoints = value ?? false;
                    _redeemTypeValidationError =
                        !_useVenuePoints && !_useAppPoints;
                  });
                },
              ),
              Text(
                'Feathers',
                style: TextStyle(color: label(true), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPointsInputs() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_useVenuePoints)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVenueField(),

              if (_showValidationMessages &&
                  _useVenuePoints &&
                  (_venuePointsController.text.isEmpty ||
                      (int.tryParse(_venuePointsController.text) != null &&
                          int.parse(_venuePointsController.text) < 5)))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _venuePointsController.text.isEmpty
                        ? 'Please enter venue points.'
                        : 'Minimum 5 points.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (_useVenuePoints && _useAppPoints) const SizedBox(width: 16),
      if (_useAppPoints)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeathersField(),
              if (_showValidationMessages &&
                  _useAppPoints &&
                  (_appPointsController.text.isEmpty ||
                      (int.tryParse(_appPointsController.text) != null &&
                          int.parse(_appPointsController.text) < 5)))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _appPointsController.text.isEmpty
                        ? 'Please enter feathers.'
                        : 'Minimum 5 points.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: Design.getTextColor(context).withOpacity(0.5),
      fontSize: 14,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    // filled: true,
    // fillColor: Design.getSurfaceColor(context),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Design.getBorderColor(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Design.getBorderColor(context)),
    ),

    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Design.errorRed),
    ),
  );

  Widget _buildVenueField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        decoration: BoxDecoration(
          color: Design.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                _showValidationMessages && _venuePointsController.text.isEmpty
                    ? Design.errorRed
                    : Design.getBorderColor(context),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
            ),
          ),
          child: TextFormField(
            controller: _venuePointsController,
            style: TextStyle(color: Design.getTextColor(context), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Min limit is 5',
              hintStyle: TextStyle(
                color: Design.getTextColor(context).withOpacity(0.5),
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 15,
              ),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            validator: (v) => null,
            onChanged: (value) {
              setState(() {
                if (_showValidationMessages &&
                    _venuePointsController.text.isEmpty) {
                  _showValidationMessages = false;
                }
              });
            },
          ),
        ),
      ),
    ],
  );

  Widget _buildFeathersField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        decoration: BoxDecoration(
          color: Design.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                _showValidationMessages && _appPointsController.text.isEmpty
                    ? Design.errorRed
                    : Design.getBorderColor(context),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
            ),
          ),
          child: TextFormField(
            controller: _appPointsController,
            style: TextStyle(color: Design.getTextColor(context), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Min limit is 5',
              hintStyle: TextStyle(
                color: Design.getTextColor(context).withOpacity(0.5),
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 15,
              ),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            validator: (v) => null,
            onChanged: (value) {
              setState(() {
                if (_showValidationMessages &&
                    _appPointsController.text.isEmpty) {
                  _showValidationMessages = false;
                }
              });
            },
          ),
        ),
      ),
    ],
  );
  Widget _buildTitleField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        decoration: BoxDecoration(
          color: Design.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                _showValidationMessages && _nameController.text.isEmpty
                    ? Design.errorRed
                    : Design.getBorderColor(context),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
            ),
          ),
          child: TextFormField(
            controller: _nameController,
            style: TextStyle(color: Design.getTextColor(context), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Title of offer',
              hintStyle: TextStyle(
                color: Design.getTextColor(context).withOpacity(0.5),
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 15,
              ),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            validator: (v) => null,
            onChanged: (value) {
              setState(() {
                if (_showValidationMessages && _nameController.text.isEmpty) {
                  _showValidationMessages = false;
                }
              });
            },
          ),
        ),
      ),
    ],
  );

  Widget _buildDescriptionField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        decoration: BoxDecoration(
          color: Design.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                _showValidationMessages && _descriptionController.text.isEmpty
                    ? Design.errorRed
                    : Design.getBorderColor(context),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
            ),
          ),
          child: TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            style: TextStyle(color: Design.getTextColor(context), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Offer description',
              hintStyle: TextStyle(
                color: Design.getTextColor(context).withOpacity(0.5),
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 15,
              ),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            validator: (v) => null,
            onChanged: (value) {
              setState(() {
                if (_showValidationMessages &&
                    _descriptionController.text.isEmpty) {
                  _showValidationMessages = false;
                }
              });
            },
          ),
        ),
      ),
    ],
  );

  Widget _buildRedemptionLimit() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Redemption Limit ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Design.getTextColor(context),
              ),
            ),
            TextSpan(
              text: '(Leave blank for unlimited)',
              style: TextStyle(
                fontSize: 14,
                color: Design.getTextColor(context).withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _redemptionLimitController,
        keyboardType: TextInputType.number,
        style: TextStyle(color: Design.getTextColor(context), fontSize: 14),
        decoration: _inputDecoration('Redemption Limit'),
        validator: (v) {
          if (v != null && v.isNotEmpty) {
            final p = int.tryParse(v);
            if (p == null || p < -1) return 'Invalid';
          }
          return null;
        },
      ),
    ],
  );

  Widget _buildImagePicker() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Upload Picture',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Design.getTextColor(context),
        ),
      ),
      const SizedBox(height: 8),
      _pickedImage == null
          ? Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Design.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    _imageValidationError
                        ? Design.errorRed
                        : Design.getBorderColor(context),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.camera_alt,
                size: 50,
                color: Design.getTextColor(context).withOpacity(0.5),
              ),
              onPressed: () {
                _pickImage();
                _scrollToBottom();
              },
            ),
          )
          : InkWell(
            onTap: () {
              _pickImage();
              _scrollToBottom();
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(_pickedImage!.path),
                  width: 80,
                  height: 80,
                  filterQuality: FilterQuality.high,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
    ],
  );
}
