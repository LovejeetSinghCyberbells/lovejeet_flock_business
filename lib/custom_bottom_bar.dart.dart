// import 'package:flock/HomeScreen.dart';
// import 'package:flock/checkIns.dart';
// import 'package:flutter/material.dart';

// import 'package:flock/profile_screen.dart' as profile;
// import 'package:flock/venue.dart' as venue;

// class CustomBottomBar extends StatelessWidget {
//   final int currentIndex;
//   const CustomBottomBar({Key? key, required this.currentIndex}) : super(key: key);

//   void _onItemTapped(BuildContext context, int index) {
//     // Update this logic to navigate to your actual pages:
//     switch (index) {
//       case 0:
//         // Example: TabDashboard
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (context) =>  TabDashboard()),
//         );
//         break;
//       case 1:
//         // Example: Venues
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (context) => venue.TabEggScreen()),
//         );
//         break;
//       case 2:
//         // Example: CheckInScreen
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (context) => const CheckInsScreen()),
//         );
//         break;
//       case 3:
//         // Example: My Profile
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (context) => profile.TabProfile()),
//         );
//         break;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return BottomAppBar(
//       // Gives the FAB a notch to "dock" into
//       shape: const CircularNotchedRectangle(),
//       notchMargin: 6.0,
//       child: SizedBox(
//         height: 60,
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: <Widget>[
//             // 1) Dashboard
//             _buildNavItem(
//               context,
//               icon: Icons.grid_view_rounded,
//               label: "Dashboard",
//               index: 0,
//             ),

//             // 2) Venues
//             _buildNavItem(
//               context,
//               icon: Icons.apartment,
//               label: "Venues",
//               index: 1,
//             ),

//             // Spacer for the center FAB
//             const SizedBox(width: 50),

//             // 3) Check In
//             _buildNavItem(
//               context,
//               icon: Icons.login_outlined,
//               label: "Check In",
//               index: 2,
//             ),

//             // 4) My Profile
//             _buildNavItem(
//               context,
//               icon: Icons.person,
//               label: "My Profile",
//               index: 3,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildNavItem(
//     BuildContext context, {
//     required IconData icon,
//     required String label,
//     required int index,
//   }) {
//     final bool isActive = (currentIndex == index);
//     final Color activeColor = const Color.fromRGBO(255, 130, 16, 1);
//     final Color inactiveColor = Colors.grey;

//     return InkWell(
//       onTap: () => _onItemTapped(context, index),
//       child: SizedBox(
//         width: 60, // Adjust if you want more spacing
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               icon,
//               color: isActive ? activeColor : inactiveColor,
//             ),
//             Text(
//               label,
//               style: TextStyle(
//                 color: isActive ? activeColor : inactiveColor,
//                 fontSize: 10, // Adjust text size if needed
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
