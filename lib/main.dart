import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const PortonianApp());
}

class PortonianApp extends StatelessWidget {
  const PortonianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.red),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String statusText = "MESH IDLE";
  Color statusColor = Colors.grey;
  int nodesFound = 0;

  void startMesh() async {
    setState(() {
      statusText = "SCANNING...";
      statusColor = Colors.orange;
    });

    // This tells the phone to listen for 5 seconds
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        nodesFound = results.length;
        statusText = "MESH ACTIVE";
        statusColor = Colors.green;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PORTONIAN PUSH")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_tethering, size: 100, color: statusColor),
            const SizedBox(height: 20),
            Text("Status: $statusText", 
                 style: TextStyle(fontSize: 22, color: statusColor, fontWeight: FontWeight.bold)),
            Container(
  padding: const EdgeInsets.all(15),
  decoration: BoxDecoration(
    color: Colors.red.withOpacity(0.1),
    border: Border.all(color: Colors.red),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Text(
    "$nodesFound NODES IN RANGE",
    style: const TextStyle(
      color: Colors.red,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    ),
  ),
),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: startMesh,
              child: const Text("ACTIVATE BEACON", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}