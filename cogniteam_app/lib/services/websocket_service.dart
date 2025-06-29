import 'dart:async';
import 'dart:convert'; // For jsonDecode
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cogniteam_app/models/message.dart'; // For parsing incoming messages

// Example: ws://127.0.0.1:8000/api/v1/ws/chat/{group_id}/{token}
// Note: The backend /ws prefix is /api/v1/ws if consistent with other HTTP routes.
// The router for chat.py was defined with prefix="/ws", so base URL + "/ws/chat/..."
// BACKEND_WEBSOCKET_URL_BASE=ws://127.0.0.1:8000/api/v1/ws (or just ws://127.0.0.1:8000 if prefix is absolute)

class WebSocketService {
  WebSocketChannel? _channel;
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

  WebSocketService(this._groupId) {
    _currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    fb_auth.FirebaseAuth.instance.authStateChanges().listen((user) {
      _currentUser = user;
      if (user == null && _isConnected) {
        disconnect(); // Disconnect if user logs out
      }
    });
  }

  Future<void> connect() async {
    if (_isConnected || _currentUser == null) {
      print("WebSocketService: Already connected or no user. Cannot connect.");
      if (_currentUser == null) _connectionStatusController.add(false);
      return;
    }

    try {
      final String? idToken =
          await _currentUser!.getIdToken(true); // Force refresh token
      if (idToken == null) {
        print("WebSocketService: Failed to get ID token. Cannot connect.");
        _connectionStatusController.add(false);
        return;
      }

      // Determine base WebSocket URL (ws:// or wss://)
      String wsBaseUrl = dotenv.env['BACKEND_WEBSOCKET_URL'] ?? "";

      if (wsBaseUrl.isEmpty) {
        // Fallback to HTTP base URL and convert to WebSocket
        final httpBaseUrl = dotenv.env['BACKEND_BASE_URL'] ?? "";
        if (httpBaseUrl.isNotEmpty) {
          // Remove /api/v1 from the end if present
          wsBaseUrl = httpBaseUrl.replaceAll('/api/v1', '');
        } else {
          print(
              "Warning: No backend URL configured. Using default development URL.");
          wsBaseUrl = "http://localhost:8000";
        }
      }

      // Convert http/https to ws/wss
      if (wsBaseUrl.startsWith('https://')) {
        wsBaseUrl = wsBaseUrl.replaceFirst('https://', 'wss://');
      } else if (wsBaseUrl.startsWith('http://')) {
        wsBaseUrl = wsBaseUrl.replaceFirst('http://', 'ws://');
      }

      // Ensure we have the correct WebSocket URL format
      // The backend expects: wss://host:port/api/v1/ws/chat/{groupId}/{token}
      final String webSocketUrl =
          "$wsBaseUrl/api/v1/ws/chat/$_groupId/$idToken";
      print("WebSocketService: Connecting to $webSocketUrl");

      _channel = WebSocketChannel.connect(Uri.parse(webSocketUrl));
      _isConnected = true;
      _connectionStatusController.add(true);
      print("WebSocketService: Connected to $_groupId.");

      _channel!.stream.listen(
        (data) {
          // Assuming data is a JSON string representing a Message object
          try {
            final Map<String, dynamic> messageJson = jsonDecode(data as String);
            final Message message = Message.fromJson(messageJson);
            _messageStreamController.add(message);
          } catch (e) {
            print(
                "WebSocketService: Error parsing message data: $e. Data: $data");
          }
        },
        onDone: () {
          print("WebSocketService: Channel for $_groupId closed by server.");
          _isConnected = false;
          _connectionStatusController.add(false);
        },
        onError: (error) {
          print("WebSocketService: Channel for $_groupId error: $error");
          _isConnected = false;
          _connectionStatusController.add(false);
          // Consider attempting to reconnect here, with backoff strategy.
        },
        cancelOnError: true, // Automatically cancels subscription on error
      );
    } catch (e) {
      print("WebSocketService: Connection error for $_groupId: $e");
      _isConnected = false;
      _connectionStatusController.add(false);
    }
  }

  void sendMessage(String messageContent) {
    if (_channel != null && _isConnected) {
      print("WebSocketService: Sending message to $_groupId: $messageContent");
      _channel!.sink
          .add(messageContent); // Backend expects raw text message content
    } else {
      print(
          "WebSocketService: Cannot send message. Not connected or channel is null.");
      // Optionally buffer messages to send upon reconnection.
    }
  }

  void disconnect() {
    if (_channel != null) {
      print("WebSocketService: Disconnecting from $_groupId.");
      _channel!.sink.close();
      _isConnected = false;
      _connectionStatusController.add(false);
    }
  }

  void dispose() {
    print("WebSocketService: Disposing service for $_groupId.");
    disconnect();
    _messageStreamController.close();
    _connectionStatusController.close();
  }
}
