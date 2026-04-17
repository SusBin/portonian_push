import 'dart:async';

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
  final List<ScanResult> discoveredDevices = <ScanResult>[];
  final List<String> scanLogs = <String>[];
  StreamSubscription<List<ScanResult>>? scanResultsSubscription;

  @override
  void initState() {
    super.initState();

    // Keep listening for scan results so the device list and node count update in real time.
    scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) {
        return;
      }

      setState(() {
        nodesFound = results.length;
        discoveredDevices
          ..clear()
          ..addAll(results);
        statusText = results.isEmpty ? "SCANNING..." : "MESH ACTIVE";
        statusColor = results.isEmpty ? Colors.orange : Colors.green;
      });

      addLog("Scan update: ${results.length} device(s) in range");
    });
  }

  void addLog(String message) {
    // Store a short timestamped log entry for the on-screen scan history and debug output.
    final String entry = "${DateTime.now().toIso8601String()} $message";
    debugPrint(entry);

    setState(() {
      scanLogs.insert(0, entry);
      if (scanLogs.length > 25) {
        scanLogs.removeLast();
      }
    });
  }

  void startMesh() async {
    setState(() {
      statusText = "SCANNING...";
      statusColor = Colors.orange;
      discoveredDevices.clear();
    });

    // This is the basic BLE scan step used for peer discovery in the current build.
    addLog("Starting BLE scan for nearby devices");

    // The scan only runs for a short time here so it can be tested in a controlled way.
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  @override
  void dispose() {
    scanResultsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PORTONIAN PUSH")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Icon(Icons.wifi_tethering, size: 100, color: statusColor),
            const SizedBox(height: 20),
            Text(
              "Status: $statusText",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$nodesFound NODES IN RANGE",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              onPressed: startMesh,
              child: const Text(
                "ACTIVATE BEACON",
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 28),
            // This section shows the peers detected during the current scan.
            const Text(
              "Discovered Devices",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (discoveredDevices.isEmpty)
              const Text(
                "No devices discovered yet.",
                style: TextStyle(color: Colors.white70),
              )
            else
              ...discoveredDevices.map(
                (result) => Card(
                  color: Colors.white10,
                  child: ListTile(
                    leading: const Icon(
                      Icons.device_unknown,
                      color: Colors.redAccent,
                    ),
                    title: Text(
                      result.device.platformName.isNotEmpty
                          ? result.device.platformName
                          : "Unnamed device",
                    ),
                    subtitle: Text(
                      "ID: ${result.device.remoteId.str} • RSSI: ${result.rssi}",
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 28),
            // The log list gives a simple record of scan activity for evidence.
            const Text(
              "Scan Log",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: scanLogs.isEmpty
                    ? [
                        const Text(
                          "No scan logs yet.",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ]
                    : scanLogs
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                entry,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          )
                          .toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
