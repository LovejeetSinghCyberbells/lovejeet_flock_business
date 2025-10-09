// import 'package:flutter/material.dart';

// class AppDrawer extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Drawer(
//       child: Column(
//         children: [
//           UserAccountsDrawerHeader(
//             decoration: BoxDecoration(color: const Color.fromRGBO(255, 130, 16, 1)),
//             accountName: Text(
//               "Amit Kumar",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
//             ),
//             accountEmail: Text(
//               "iitianamit2019@gmail.com",
//               style: TextStyle(fontSize: 14, color: Colors.black54),
//             ),
//             currentAccountPicture: CircleAvatar(
//               backgroundColor: Colors.white,
//               child: Icon(Icons.person, size: 40, color: Colors.black),
//             ),
//           ),
//           _buildDrawerItem(Icons.percent, "My Offers", context),
//           _buildDrawerItem(Icons.favorite_border, "Saved Offers", context),
//           _buildDrawerItem(Icons.question_answer, "FAQs", context),
//           _buildDrawerItem(Icons.report, "Report", context),
//           _buildDrawerItem(Icons.play_circle_filled, "How To", context),
//           _buildDrawerItem(Icons.location_city, "Request venue", context),
//           _buildDrawerItem(Icons.support_agent, "Support", context),
//           Divider(),
//           _buildDrawerItem(Icons.exit_to_app, "Logout", context, isLogout: true),
//         ],
//       ),
//     );
//   }

//   Widget _buildDrawerItem(IconData icon, String title, BuildContext context, {bool isLogout = false}) {
//     return ListTile(
//       leading: Icon(icon, color: Colors.grey[700]),
//       title: Text(title, style: TextStyle(fontSize: 16, color: Colors.black87)),
//       onTap: () {
//         Navigator.pop(context); // Close drawer
//         if (isLogout) {
//           // Handle logout logic
//           Navigator.pushReplacementNamed(context, '/login');
//         }
//       },
//     );
//   }
// }
