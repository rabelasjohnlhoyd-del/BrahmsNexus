import 'package:flutter/material.dart';

void main() {
  runApp(const BrahmsNexusApp());
}

class BrahmsNexusApp extends StatelessWidget {
  const BrahmsNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brahms Nexus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 60% Dominant Color: Off-white/Cream para malinis at maaliwalas
        scaffoldBackgroundColor: const Color(0xFFFAF0E6),
        fontFamily: 'Roboto', // Pwede ninyong palitan ng iOS font tulad ng Cupertino
      ),
      home: const StaffMainScreen(),
    );
  }
}

class StaffMainScreen extends StatefulWidget {
  const StaffMainScreen({super.key});

  @override
  State<StaffMainScreen> createState() => _StaffMainScreenState();
}

class _StaffMainScreenState extends State<StaffMainScreen> {
  int _selectedIndex = 0;

  // Ito ang mga dummy screens na papalitan ninyo ng totoong UI mamaya
  static const List<Widget> _widgetOptions = <Widget>[
    Center(child: Text('Home / Sales: Record Total Portions Sold')), //[cite: 5]
    Center(child: Text('Inventory: Remaining Stocks & Restock')), //[cite: 5]
    Center(child: Text('Announcements: Daily Updates')), //[cite: 5]
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Brahms Nexus',
            style: TextStyle(
                color: Color(0xFFA0522D), // 10% Accent Color para sa text highlights
                fontWeight: FontWeight.bold
            )
        ),
        backgroundColor: const Color(0xFFFAF0E6), // 60% Dominant Color
        elevation: 0, // Tinanggal ang shadow para flat at iOS-look
        centerTitle: true,
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_rounded),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_rounded),
            label: 'Updates',
          ),
        ],
        currentIndex: _selectedIndex,
        // Dito natin in-apply ang iOS style at 60-30-10 rules
        backgroundColor: const Color(0xFFFAF0E6), // 60% Dominant (Background)
        unselectedItemColor: const Color(0xFFD2B48C), // 30% Secondary (Unselected Tabs)
        selectedItemColor: const Color(0xFFA0522D), // 10% Accent (Active Tab)
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Pinipigilan ang animation para stable tulad sa iOS
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
      ),
    );
  }
}