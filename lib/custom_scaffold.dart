import 'package:flutter/material.dart';
import 'package:flock/add_offer.dart';
import 'package:flock/add_venue.dart' as addVenue;
import 'package:flock/venue.dart' as venue;
import 'package:flock/checkIns.dart';
import 'package:flock/profile_screen.dart' as profile;
import 'package:flock/HomeScreen.dart';

class Design {
  static const Color primaryColorOrange = Color.fromRGBO(255, 152, 0, 1);
  static const Color black = Colors.black;
  static const Color white = Colors.white;
  static const Color lightPurple = Color(0xFFF0F0F5);
  static const Color blue = Color(0xFF2A4CE1);

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

class _CustomFABLocation extends FloatingActionButtonLocation {
  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX =
        (scaffoldGeometry.scaffoldSize.width -
            scaffoldGeometry.floatingActionButtonSize.width) /
        2;
    final double fabY =
        scaffoldGeometry.contentBottom -
        scaffoldGeometry.floatingActionButtonSize.height / 2 +
        (scaffoldGeometry.scaffoldSize.height * 0.01);
    return Offset(fabX, fabY);
  }
}

class CustomScaffold extends StatelessWidget {
  static final AssetImage _bird = const AssetImage('assets/bird.png');
  final Widget body;
  final int currentIndex;
  final bool canAddVenue;
  final bool canAddOffer;

  const CustomScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.canAddVenue,
    required this.canAddOffer,
  });

  BuildContext get context => context;

  @override
  Widget build(BuildContext context) {
    precacheImage(_bird, context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Design.getBackgroundColor(context),
      body: SafeArea(top: true, bottom: true, child: body),
      floatingActionButtonLocation: _CustomFABLocation(),
      floatingActionButton: GestureDetector(
        onTap: () {
          canAddOffer == false && canAddVenue == false
              ? Container()
              : showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (BuildContext context) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Stack(
                      children: [
                        Positioned(
                          bottom: MediaQuery.of(context).size.height * 0.14,
                          left: screenWidth * 0.04,
                          right: screenWidth * 0.04,
                          child: GestureDetector(
                            onTap: () {}, // Prevent tap-through to dismiss
                            child: Container(
                              padding: EdgeInsets.all(screenWidth * 0.02),
                              decoration: BoxDecoration(
                                color: Design.getSurfaceColor(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Design.getBorderColor(context),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.black.withOpacity(0.3)
                                            : Colors.black.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  canAddVenue == false
                                      ? Container()
                                      : Expanded(
                                        child: _buildActionButton(
                                          context: context,
                                          icon: Icons.apartment,
                                          label: "Add Venue",
                                          iconColor: Design.blue,
                                          textColor: Design.blue,
                                          onTap: () async {
                                            Navigator.pop(context);
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) =>
                                                        addVenue.AddEggScreen(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  SizedBox(width: screenWidth * 0.03),
                                  canAddOffer == false
                                      ? Container()
                                      : Expanded(
                                        child: _buildActionButton(
                                          context: context,
                                          icon: Icons.percent,
                                          label: "Add Offer",
                                          iconColor: Design.blue,
                                          textColor: Design.blue,
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) =>
                                                        AddOfferScreen(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
        },
        child: Center(
          child: Image(
            image: _bird,
            width: screenWidth * 0.2,
            height: screenWidth * 0.2,
          ),
        ),
      ),
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: (screenHeight * 0.05) / 2,
            child: Container(
              width: screenWidth * 0.2,
              height: screenWidth * 0.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Design.getSurfaceColor(context),
                boxShadow: [
                  BoxShadow(
                    color: Design.getBorderColor(context),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          CustomBottomBar(currentIndex: currentIndex),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color textColor,
    Color? backgroundColor,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          vertical: screenWidth * 0.02,
          horizontal: screenWidth * 0.04,
        ),
        decoration: BoxDecoration(
          color: backgroundColor ?? Design.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Design.getBorderColor(context)),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: screenWidth * 0.06),
            SizedBox(width: screenWidth * 0.04),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomBottomBar extends StatelessWidget {
  final int currentIndex;

  const CustomBottomBar({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => TabDashboard()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => venue.TabEggScreen()),
        );
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CheckInsScreen()),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => profile.TabProfile()),
        );
        break;
    }
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
    required Color color,
  }) {
    final bool isActive = (currentIndex == index);
    final Color activeColor = Design.getTextColor(context);
    final Color inactiveColor =
        Theme.of(context).brightness == Brightness.dark
            ? const Color.fromRGBO(255, 140, 16, 1)
            : color;
    final screenWidth = MediaQuery.of(context).size.width;

    return InkWell(
      onTap: () => _onItemTapped(context, index),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.005,
          vertical: screenWidth * 0.015,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : inactiveColor,
              size: screenWidth * 0.08,
            ),
            SizedBox(height: screenWidth * 0.004),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontSize: screenWidth * 0.032,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      height: screenHeight * 0.08,
      decoration: BoxDecoration(
        color: Design.getSurfaceColor(context),
        boxShadow: [
          // BoxShadow(
          //   color: Design.getBorderColor(context),
          //   blurRadius: 8,
          //   offset: const Offset(0, 2),
          // ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Remove or comment out the Positioned widget with the background image
          // Positioned(
          //   top: 0,
          //   left: 0,
          //   right: 0,
          //   child: Container(
          //     color: Design.getBackgroundColor(context),
          //     child: Image.asset(
          //       Theme.of(context).brightness == Brightness.dark
          //           ? 'assets/bottom_nav_dark.png'
          //           : 'assets/bottom_nav.png',
          //       fit: BoxFit.cover,
          //       height: screenHeight * 0.14,
          //     ),
          //   ),
          // ),
          // Keep your Row of icons and labels
          Padding(
            padding: EdgeInsets.only(
              left: screenWidth * 0.05,
              right: screenWidth * 0.05,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _buildNavItem(
                  context,
                  icon: Icons.grid_view_rounded,
                  label: "Dashboard",
                  index: 0,
                  color:
                      Colors
                          .black, // You can change icon/text color for visibility
                ),
                _buildNavItem(
                  context,
                  icon: Icons.apartment,
                  label: "Venues",
                  index: 1,
                  color: Colors.black,
                ),
                SizedBox(width: screenWidth * 0.2),
                _buildNavItem(
                  context,
                  icon: Icons.login_outlined,
                  label: "Check In",
                  index: 3,
                  color: Colors.black,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.person,
                  label: "My Profile",
                  index: 4,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // @override
  // Widget build(BuildContext context) {
  //   final screenHeight = MediaQuery.of(context).size.height;
  //   final screenWidth = MediaQuery.of(context).size.width;

  //   return Container(
  //     color: Design.getBackgroundColor(context),
  //     height: screenHeight * 0.13,
  //     child: Stack(
  //       alignment: Alignment.center,
  //       children: [
  //         Positioned(
  //           top: 0,
  //           left: 0,
  //           right: 0,
  //           child: Container(
  //             color: Design.getBackgroundColor(context),
  //             child: Image.asset(
  //               Theme.of(context).brightness == Brightness.dark
  //                   ? 'assets/bottom_nav_dark.png'
  //                   : 'assets/bottom_nav.png',
  //               fit: BoxFit.cover,
  //               height: screenHeight * 0.14,
  //             ),
  //           ),
  //         ),
  //         Padding(
  //           padding: EdgeInsets.only(
  //             top: screenHeight * 0.035,
  //             left: screenWidth * 0.05,
  //             right: screenWidth * 0.05,
  //           ),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: <Widget>[
  //               _buildNavItem(
  //                 context,
  //                 icon: Icons.grid_view_rounded,
  //                 label: "Dashboard",
  //                 index: 0,
  //                 color: Colors.black,
  //               ),
  //               _buildNavItem(
  //                 context,
  //                 icon: Icons.apartment,
  //                 label: "Venues",
  //                 index: 1,
  //                 color: Colors.black,
  //               ),
  //               SizedBox(width: screenWidth * 0.2),
  //               _buildNavItem(
  //                 context,
  //                 icon: Icons.login_outlined,
  //                 label: "Check In",
  //                 index: 3,
  //                 color: Colors.black,
  //               ),
  //               _buildNavItem(
  //                 context,
  //                 icon: Icons.person,
  //                 label: "My Profile",
  //                 index: 4,
  //                 color: Colors.black,
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}
