import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cogniteam_app/models/message.dart';
import 'package:cogniteam_app/config/app_config.dart';

class SSEService {
  http.Client? _client;
  StreamSubscription? _subscription;
  StreamController<Message> _messageStreamController =
      StreamController<Message>.broadcast();
  Stream<Message> get messages => _messageStreamController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  final String _groupId;
  fb_auth.User? _currentUser;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 2);

  SSEService(this._groupId) {
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    _currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    fb_auth.FirebaseAuth.instance.authStateChanges().listen((user) {
      _currentUser = user;
      if (user == null && _isConnected) {
        disconnect();
      }
    });
  }

  Future<void> connect() async {
    if (_isConnected) {
      print("SSEService: Already connected to $_groupId. Skipping connection.");
      return;
    }

    if (_currentUser == null) {
      print("SSEService: No user available. Cannot connect.");
      _connectionStatusController.add(false);
      return;
    }

    // Disconnect any existing connection first
    if (_subscription != null || _client != null) {
      print(
          "SSEService: Disconnecting existing connection before reconnecting");
      disconnect();
      // Wait a bit for cleanup
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      print("SSEService: Starting connection process for group $_groupId");
      final String? idToken = await _currentUser!.getIdToken(true);
      if (idToken == null) {
        print("SSEService: Failed to get ID token. Cannot connect.");
        _connectionStatusController.add(false);
        return;
      }
      print(
          "SSEService: Got ID token successfully. Token length: ${idToken.length}");

      // Determine base URL
      String baseUrl = AppConfig.backendBaseUrl;

      // 修正: baseUrlの末尾に/api/v1が含まれている場合は重複しないようにする
      String sseUrl;
      if (baseUrl.endsWith('/api/v1')) {
        sseUrl = "${baseUrl}/sse/chat/$_groupId";
      } else {
        sseUrl = "${baseUrl}/api/v1/sse/chat/$_groupId";
      }
      print("SSEService: Connecting to $sseUrl");

      _client = http.Client();
      print("SSEService: HTTP client created");

      // Create SSE request with headers
      final request = http.Request('GET', Uri.parse(sseUrl));
      request.headers['Authorization'] = 'Bearer $idToken';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      request.headers['Connection'] = 'keep-alive';
      request.headers['Origin'] = 'https://handsonadk.web.app';
      print("SSEService: Request headers set: ${request.headers}");

      final response = await _client!.send(request);
      print("SSEService: Response received. Status: ${response.statusCode}");

      if (response.statusCode != 200) {
        throw Exception('SSE connection failed: ${response.statusCode}');
      }

      _isConnected = true;
      _connectionStatusController.add(true);
      _reconnectAttempts = 0;
      print(
          "SSEService: Connected to $_groupId successfully. Status code: ${response.statusCode}");

      // Listen to the SSE stream
      _subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          print("SSEService: Received SSE line: '$line'");
          _handleSSELine(line);
        },
        onDone: () {
          print("SSEService: SSE stream for $_groupId closed by server.");
          _handleDisconnection();
        },
        onError: (error) {
          print("SSEService: SSE stream for $_groupId error: $error");
          _handleDisconnection();
        },
      );
    } catch (e) {
      print("SSEService: Connection error for $_groupId: $e");
      print("SSEService: Error type: ${e.runtimeType}");
      if (e is http.ClientException) {
        print("SSEService: ClientException details: ${e.message}");
      }
      _handleDisconnection();
    }
  }

  void _handleSSELine(String line) {
    print("SSEService: Received SSE line: '$line'");

    // Handle keepalive messages
    if (line.trim() == ': keepalive') {
      print("SSEService: Received keepalive, connection is alive");
      return;
    }

    // Handle empty lines
    if (line.trim().isEmpty) {
      print("SSEService: Received empty line, skipping");
      return;
    }

    if (line.startsWith('data: ')) {
      final data = line.substring(6); // Remove 'data: ' prefix
      if (data.trim().isNotEmpty) {
        print("SSEService: Processing SSE data: '$data'");
        try {
          final Map<String, dynamic> messageJson = jsonDecode(data);
          print("SSEService: Parsed JSON: $messageJson");
          final Message message = Message.fromJson(messageJson);
          print(
              "SSEService: Created Message object: ${message.messageId} - ${message.content}");
          _messageStreamController.add(message);
          print("SSEService: Message added to stream controller");
        } catch (e) {
          print("SSEService: Error parsing message data: $e. Data: $data");
        }
      } else {
        print("SSEService: Empty data line, skipping");
      }
    } else {
      print("SSEService: Non-data line, skipping: '$line'");
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _connectionStatusController.add(false);
    _subscription?.cancel();
    _client?.close();

    // Attempt to reconnect if not manually disconnected
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      print(
          "SSEService: Attempting to reconnect (${_reconnectAttempts}/$_maxReconnectAttempts)");
      _reconnectTimer = Timer(_reconnectDelay, () {
        print("SSEService: Executing reconnect attempt ${_reconnectAttempts}");
        connect();
      });
    } else {
      print("SSEService: Max reconnection attempts reached. Giving up.");
    }
  }

  void disconnect() {
    print("SSEService: Disconnecting from $_groupId.");
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _client?.close();
    _isConnected = false;
    _connectionStatusController.add(false);
  }

  void dispose() {
    print("SSEService: Disposing service for $_groupId.");
    disconnect();
    _messageStreamController.close();
    _connectionStatusController.close();
  }
}

// シミュレーション通知用のSSEサービス
class SimulationSSEService {
  static final SimulationSSEService _instance =
      SimulationSSEService._internal();
  factory SimulationSSEService() => _instance;
  SimulationSSEService._internal();

  final StreamController<Map<String, dynamic>> _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  StreamSubscription? _subscription;
  http.Client? _client;
  bool _isConnected = false;
  bool _isManuallyDisconnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  final Duration _reconnectDelay = const Duration(seconds: 5);

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  bool get isConnected => _isConnected;

  fb_auth.User? _currentUser;

  void _initializeAuthListener() {
    _currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    fb_auth.FirebaseAuth.instance.authStateChanges().listen((user) {
      _currentUser = user;
      if (user == null && _isConnected) {
        disconnect();
      }
    });
  }

  Future<void> connect() async {
    if (_isConnected) {
      print("SimulationSSEService: Already connected. Skipping connection.");
      return;
    }

    if (_currentUser == null) {
      print("SimulationSSEService: No user available. Cannot connect.");
      _connectionStatusController.add(false);
      return;
    }

    // Reset manual disconnect flag
    _isManuallyDisconnected = false;

    // Disconnect any existing connection first
    if (_subscription != null || _client != null) {
      print(
          "SimulationSSEService: Disconnecting existing connection before reconnecting");
      disconnect();
      // Wait a bit for cleanup
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      print("SimulationSSEService: Starting connection process");
      final String? idToken = await _currentUser!.getIdToken(true);
      if (idToken == null) {
        print("SimulationSSEService: Failed to get ID token. Cannot connect.");
        _connectionStatusController.add(false);
        return;
      }
      print(
          "SimulationSSEService: Got ID token successfully. Token length: ${idToken.length}");

      // Determine base URL
      String baseUrl = AppConfig.backendBaseUrl;

      // 修正: baseUrlの末尾に/api/v1が含まれている場合は重複しないようにする
      String sseUrl;
      if (baseUrl.endsWith('/api/v1')) {
        sseUrl = "${baseUrl}/sse/simulation";
      } else {
        sseUrl = "${baseUrl}/api/v1/sse/simulation";
      }
      print("SimulationSSEService: Connecting to $sseUrl");

      // First, try to make a simple OPTIONS request to check CORS
      try {
        final optionsClient = http.Client();
        final optionsResponse = await optionsClient
            .send(http.Request('OPTIONS', Uri.parse(sseUrl)));
        print(
            "SimulationSSEService: OPTIONS request status: ${optionsResponse.statusCode}");
        optionsClient.close();
      } catch (e) {
        print("SimulationSSEService: OPTIONS request failed: $e");
        // Continue anyway, as the actual request might still work
      }

      _client = http.Client();
      print("SimulationSSEService: HTTP client created");

      // Create SSE request with headers
      final request = http.Request('GET', Uri.parse(sseUrl));
      request.headers['Authorization'] = 'Bearer $idToken';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      request.headers['Connection'] = 'keep-alive';
      request.headers['Origin'] = 'https://handsonadk.web.app';
      print("SimulationSSEService: Request headers set: ${request.headers}");

      final response = await _client!.send(request);
      print(
          "SimulationSSEService: Response received. Status: ${response.statusCode}");

      if (response.statusCode != 200) {
        throw Exception(
            'Simulation SSE connection failed: ${response.statusCode}');
      }

      _isConnected = true;
      _connectionStatusController.add(true);
      _reconnectAttempts = 0;
      print(
          "SimulationSSEService: Connected successfully. Status code: ${response.statusCode}");

      // Listen to the SSE stream
      _subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          print("SimulationSSEService: Raw SSE line received: '$line'");
          _handleSSELine(line);
        },
        onDone: () {
          print("SimulationSSEService: SSE stream closed by server.");
          _handleConnectionClosed();
        },
        onError: (error) {
          print("SimulationSSEService: SSE stream error: $error");
          _handleConnectionClosed();
        },
      );
    } catch (e) {
      print("SimulationSSEService: Connection error: $e");
      print("SimulationSSEService: Error type: ${e.runtimeType}");
      if (e is http.ClientException) {
        print("SimulationSSEService: ClientException details: ${e.message}");
      }
      _handleConnectionClosed();
    }
  }

  void _handleSSELine(String line) {
    print("SimulationSSEService: Received SSE line: '$line'");

    // Handle keepalive messages
    if (line.trim() == ': keepalive') {
      print("SimulationSSEService: Received keepalive, connection is alive");
      return;
    }

    // Handle empty lines
    if (line.trim().isEmpty) {
      print("SimulationSSEService: Received empty line, skipping");
      return;
    }

    if (line.startsWith('data: ')) {
      final data = line.substring(6); // Remove 'data: ' prefix
      if (data.trim().isNotEmpty) {
        print("SimulationSSEService: Processing SSE data: '$data'");
        try {
          final Map<String, dynamic> notificationJson = jsonDecode(data);
          print("SimulationSSEService: Parsed JSON: $notificationJson");
          _notificationStreamController.add(notificationJson);
          print(
              "SimulationSSEService: Notification added to stream controller");
        } catch (e) {
          print(
              "SimulationSSEService: Error parsing notification data: $e. Data: $data");
        }
      } else {
        print("SimulationSSEService: Empty data line, skipping");
      }
    } else {
      print("SimulationSSEService: Non-data line, skipping: '$line'");
    }
  }

  void _handleConnectionClosed() {
    print("SimulationSSEService: Connection closed");
    _isConnected = false;

    // Only attempt reconnection if we haven't been manually disconnected
    if (!_isManuallyDisconnected) {
      print(
          "SimulationSSEService: Connection lost, attempting to reconnect...");
      _scheduleReconnect();
    } else {
      print(
          "SimulationSSEService: Connection manually closed, not reconnecting");
    }
  }

  void disconnect() {
    print("SimulationSSEService: Disconnecting.");
    _isManuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _client?.close();
    _isConnected = false;
    _connectionStatusController.add(false);
  }

  void dispose() {
    print("SimulationSSEService: Disposing service.");
    disconnect();
    _notificationStreamController.close();
    _connectionStatusController.close();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      print(
          "SimulationSSEService: Scheduling reconnect attempt ${_reconnectAttempts}/$_maxReconnectAttempts");
      _reconnectTimer = Timer(_reconnectDelay, () {
        print(
            "SimulationSSEService: Executing reconnect attempt ${_reconnectAttempts}");
        connect();
      });
    } else {
      print(
          "SimulationSSEService: Max reconnection attempts reached. Giving up.");
    }
  }
}
