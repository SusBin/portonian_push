import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

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

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  static const String nearbyServiceId = "com.portonian.push.alerts";

  String statusText = "MESH IDLE";
  Color statusColor = Colors.grey;
  int nodesFound = 0;

  final List<ScanResult> discoveredDevices = <ScanResult>[];
  final List<String> scanLogs = <String>[];
  final List<String> receivedAlerts = <String>[];
  final Set<String> seenAlertIds = <String>{};
  final Map<String, ConnectionInfo> connectedEndpoints =
      <String, ConnectionInfo>{};
  final Set<String> pendingConnectionIds = <String>{};

  final TextEditingController alertTextController = TextEditingController();
  final String nodeId = "NODE-${DateTime.now().millisecondsSinceEpoch}";
  final Strategy nearbyStrategy = Strategy.P2P_CLUSTER;
  final Nearby nearby = Nearby();

  StreamSubscription<List<ScanResult>>? scanResultsSubscription;
  Timer? queuedSendRetryTimer;
  String? queuedAlertMessage;
  bool isRecoveringNearby = false;
  bool alertChannelReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    // Nearby Connections in this prototype is Android-only.
    if (!kIsWeb && Platform.isAndroid) {
      initializeAlertChannel();
    } else {
      addLog("Offline alert channel is only configured for Android devices");
    }
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb && Platform.isAndroid) {
      addLog("App resumed. Re-checking nearby channel state.");
      recoverNearbyChannel(reason: "app resumed");
    }
  }

  Future<void> recoverNearbyChannel({required String reason}) async {
    if (isRecoveringNearby) {
      return;
    }

    isRecoveringNearby = true;
    addLog("Recovery started: $reason");

    try {
      await nearby.stopDiscovery();
      await nearby.stopAdvertising();
      await nearby.stopAllEndpoints();

      setState(() {
        connectedEndpoints.clear();
        pendingConnectionIds.clear();
      });

      await initializeAlertChannel();
      flushQueuedAlertIfPossible();
    } catch (error) {
      addLog("Recovery failed: $error");
    } finally {
      isRecoveringNearby = false;
    }
  }

  void queueAlertForRetry(String message) {
    queuedAlertMessage = message;
    addLog("Alert queued until a nearby peer reconnects");

    queuedSendRetryTimer?.cancel();
    queuedSendRetryTimer = Timer(const Duration(seconds: 6), () {
      flushQueuedAlertIfPossible();
      if (queuedAlertMessage != null) {
        recoverNearbyChannel(reason: "queued alert retry");
      }
    });
  }

  Future<void> flushQueuedAlertIfPossible() async {
    if (queuedAlertMessage == null || connectedEndpoints.isEmpty) {
      return;
    }

    final String message = queuedAlertMessage!;
    queuedAlertMessage = null;
    await sendAlertMessage(message, isRetry: true);
  }

  Future<void> initializeAlertChannel() async {
    final bool permissionsGranted = await requestNearbyPermissions();
    if (!permissionsGranted) {
      addLog("Alert channel blocked: required permissions not granted");
      return;
    }

    addLog("Starting nearby advertise + discovery for offline alerts");

    try {
      final bool isAdvertising = await nearby.startAdvertising(
        nodeId,
        nearbyStrategy,
        onConnectionInitiated: onConnectionInit,
        onConnectionResult: onConnectionResult,
        onDisconnected: onDisconnected,
        serviceId: nearbyServiceId,
      );

      final bool isDiscovering = await nearby.startDiscovery(
        nodeId,
        nearbyStrategy,
        onEndpointFound: onEndpointFound,
        onEndpointLost: onEndpointLost,
        serviceId: nearbyServiceId,
      );

      setState(() {
        alertChannelReady = isAdvertising || isDiscovering;
      });

      addLog("Nearby advertise: $isAdvertising, discovery: $isDiscovering");
    } catch (error) {
      addLog("Alert channel failed to start: $error");
    }
  }

  Future<bool> requestNearbyPermissions() async {
    final List<Permission> essentialPermissions = <Permission>[
      Permission.locationWhenInUse,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ];

    final List<Permission> optionalPermissions = <Permission>[
      Permission.bluetooth,
      Permission.nearbyWifiDevices,
    ];

    final Map<Permission, PermissionStatus> essentialStatuses =
        await essentialPermissions.request();
    final Map<Permission, PermissionStatus> optionalStatuses =
        await optionalPermissions.request();

    final List<String> deniedEssential = essentialStatuses.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => permissionLabel(entry.key, entry.value))
        .toList();

    if (deniedEssential.isNotEmpty) {
      addLog("Missing required permissions: ${deniedEssential.join(', ')}");
      addLog(
        "Tip: open app permissions in Android settings and allow Nearby + Location",
      );
      return false;
    }

    final List<String> deniedOptional = optionalStatuses.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => permissionLabel(entry.key, entry.value))
        .toList();

    if (deniedOptional.isNotEmpty) {
      addLog("Optional permissions not granted: ${deniedOptional.join(', ')}");
    }

    final ServiceStatus locationServiceStatus =
        await Permission.locationWhenInUse.serviceStatus;
    if (!locationServiceStatus.isEnabled) {
      addLog(
        "Location service is OFF. Nearby may fail until Location is enabled.",
      );
    }

    return true;
  }

  String permissionLabel(Permission permission, PermissionStatus status) {
    String name;
    if (permission == Permission.locationWhenInUse) {
      name = "Location";
    } else if (permission == Permission.bluetoothAdvertise) {
      name = "Bluetooth Advertise";
    } else if (permission == Permission.bluetoothConnect) {
      name = "Bluetooth Connect";
    } else if (permission == Permission.bluetoothScan) {
      name = "Bluetooth Scan";
    } else if (permission == Permission.bluetooth) {
      name = "Bluetooth";
    } else if (permission == Permission.nearbyWifiDevices) {
      name = "Nearby Wi-Fi Devices";
    } else {
      name = permission.toString();
    }

    if (status.isPermanentlyDenied) {
      return "$name (permanently denied)";
    }

    return "$name (${status.name})";
  }

  void onConnectionInit(String endpointId, ConnectionInfo info) {
    // auto-accept here to keep testing simple but in a real app ask user about each connection.
    setState(() {
      connectedEndpoints[endpointId] = info;
      pendingConnectionIds.remove(endpointId);
    });

    addLog("Connection initiated by ${info.endpointName} ($endpointId)");

    nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (String id, Payload payload) {
        if (payload.type != PayloadType.BYTES || payload.bytes == null) {
          return;
        }

        try {
          final String decoded = utf8.decode(payload.bytes!);
          final Map<String, dynamic> alertPayload =
              jsonDecode(decoded) as Map<String, dynamic>;

          final String alertId =
              alertPayload["alertId"] as String? ?? "unknown";
          final String senderId =
              alertPayload["senderId"] as String? ?? "unknown";
          final String message =
              alertPayload["message"] as String? ?? "(empty message)";
          final String sentAt =
              alertPayload["sentAt"] as String? ?? "unknown time";

          if (senderId == nodeId || seenAlertIds.contains(alertId)) {
            return;
          }

          seenAlertIds.add(alertId);

          setState(() {
            receivedAlerts.insert(0, "$senderId @ $sentAt -> $message");
            if (receivedAlerts.length > 15) {
              receivedAlerts.removeLast();
            }
          });

          addLog("Alert received from $senderId");
        } catch (_) {
          addLog("Ignored non-alert nearby payload");
        }
      },
      onPayloadTransferUpdate: (_, _) {},
    );
  }

  void onConnectionResult(String endpointId, Status status) {
    addLog("Connection result for $endpointId: $status");

    if (status == Status.CONNECTED) {
      setState(() {
        alertChannelReady = true;
      });

      flushQueuedAlertIfPossible();
    }
  }

  void onDisconnected(String endpointId) {
    setState(() {
      connectedEndpoints.remove(endpointId);
      pendingConnectionIds.remove(endpointId);
    });

    addLog("Disconnected from endpoint $endpointId");
    recoverNearbyChannel(reason: "endpoint disconnected");
  }

  Future<void> onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) async {
    if (pendingConnectionIds.contains(endpointId) ||
        connectedEndpoints.containsKey(endpointId)) {
      return;
    }

    pendingConnectionIds.add(endpointId);
    addLog("Endpoint found: $endpointName ($endpointId)");

    try {
      await nearby.requestConnection(
        nodeId,
        endpointId,
        onConnectionInitiated: (String id, ConnectionInfo info) {
          setState(() {
            connectedEndpoints[id] = info;
            pendingConnectionIds.remove(id);
          });

          onConnectionInit(id, info);
        },
        onConnectionResult: (String id, Status status) {
          onConnectionResult(id, status);
        },
        onDisconnected: (String id) {
          onDisconnected(id);
        },
      );
    } catch (error) {
      addLog("Connection request failed for $endpointId: $error");
      pendingConnectionIds.remove(endpointId);
    }
  }

  void onEndpointLost(String? endpointId) {
    if (endpointId == null) {
      addLog("Discovered endpoint lost: unknown endpoint");
      return;
    }

    addLog("Discovered endpoint lost: $endpointId");
    pendingConnectionIds.remove(endpointId);
  }

  Future<void> sendAlert() async {
    final String message = alertTextController.text.trim();
    await sendAlertMessage(message, isRetry: false);
  }

  Future<void> sendAlertMessage(String message, {required bool isRetry}) async {
    if (message.isEmpty) {
      addLog("Send blocked: alert message is empty");
      return;
    }

    if (!alertChannelReady || connectedEndpoints.isEmpty) {
      addLog("Send paused: no connected nearby peers");
      queueAlertForRetry(message);
      recoverNearbyChannel(reason: "send attempted with no peers");
      return;
    }

    final String alertId = "${nodeId}_${DateTime.now().millisecondsSinceEpoch}";
    final String sentAt = DateTime.now().toIso8601String();

    final Map<String, dynamic> payload = <String, dynamic>{
      "alertId": alertId,
      "senderId": nodeId,
      "sentAt": sentAt,
      "message": message,
    };

    final Uint8List bytes = Uint8List.fromList(
      utf8.encode(jsonEncode(payload)),
    );
    seenAlertIds.add(alertId);

    for (final String endpointId in List<String>.from(
      connectedEndpoints.keys,
    )) {
      await nearby.sendBytesPayload(endpointId, bytes);
    }

    setState(() {
      receivedAlerts.insert(0, "YOU @ $sentAt -> $message");
      if (receivedAlerts.length > 15) {
        receivedAlerts.removeLast();
      }
    });

    addLog("Alert sent from $nodeId");
    if (!isRetry) {
      alertTextController.clear();
    }
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
    WidgetsBinding.instance.removeObserver(this);
    scanResultsSubscription?.cancel();
    queuedSendRetryTimer?.cancel();
    nearby.stopAdvertising();
    nearby.stopDiscovery();
    nearby.stopAllEndpoints();
    alertTextController.dispose();
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
            const Text(
              "Basic Alert Transfer",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Node ID: $nodeId",
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              alertChannelReady
                  ? "Offline Channel: READY"
                  : "Offline Channel: STARTING...",
              style: TextStyle(
                color: alertChannelReady
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "Connected peers: ${connectedEndpoints.length}",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: alertTextController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Type emergency alert text",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              onPressed: sendAlert,
              child: const Text("SEND ALERT", style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 16),
            const Text(
              "Alert Feed",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (receivedAlerts.isEmpty)
              const Text(
                "No alerts sent/received yet.",
                style: TextStyle(color: Colors.white70),
              )
            else
              ...receivedAlerts.map(
                (entry) => Card(
                  color: Colors.deepOrange.withOpacity(0.12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.notification_important,
                      color: Colors.deepOrangeAccent,
                    ),
                    title: Text(entry),
                  ),
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
