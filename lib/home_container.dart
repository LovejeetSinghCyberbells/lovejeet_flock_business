// // home_container.dart  (new file – < 40 lines)
// import 'package:flutter/material.dart';
// import 'package:flock/custom_scaffold.dart';   // ← the file you posted
// import 'package:flock/HomeScreen.dart';
// import 'package:flock/venue.dart'     as venue;
// import 'package:flock/checkIns.dart';
// import 'package:flock/profile_screen.dart' as profile hide TabEggScreen;

// class HomeContainer extends StatefulWidget {
//   const HomeContainer({super.key});
//   @override
//   State<HomeContainer> createState() => _HomeContainerState();
// }

// class _HomeContainerState extends State<HomeContainer> {
//   int _index = 0;

//   // 5 pages (bird is handled inside CustomScaffold, so only 4 real pages)
//   final _pages = <Widget>[
//     TabDashboard(),
//     venue.TabEggScreen(),
//     const SizedBox(),            // placeholder for bird FAB (index 2)
//     const CheckInsScreen(),
//     profile.TabProfile(),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return CustomScaffold(
//       currentIndex: _index,
//       body: IndexedStack(          // keeps each page’s state alive
//         index: _index == 2 ? 0 : _index, // bird -> don't change page
//         children: _pages,
//       ),
//       onTabSelected: (i) {
//         if (i == 2) return;        // tapping bird => do nothing
//         setState(() => _index = i);
//       },
//     );
//   }
// }



