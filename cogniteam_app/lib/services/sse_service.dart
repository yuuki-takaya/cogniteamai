import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cogniteam_app/models/message.dart';

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
      String baseUrl =
          dotenv.env['BACKEND_BASE_URL'] ?? "http://localhost:8000";

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
          print("SSEService: Raw SSE line received: '$line'");
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
      _handleDisconnection();
    }
  }

  void _handleSSELine(String line) {
    print("SSEService: Received SSE line: '$line'");
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
        connect();
      });
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
