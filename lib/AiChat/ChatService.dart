// file: lib/AiChat/ChatService.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
// 1. 导入 socket_io_client
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// 数据模型：代表一条聊天消息 (保持不变)
class ChatMessage {
  final String text;
  final bool isUser;
  final String? imageUrl;

  ChatMessage({required this.text, required this.isUser, this.imageUrl});

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    String? imageUrl,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

/// 核心服务类 (使用 socket_io_client 重构)
class ChatService with ChangeNotifier {
  final List<ChatMessage> _messages = [];
  // 2. 将 WebSocketChannel 替换为 Socket
  IO.Socket? _socket; 
  bool _isConnecting = false;
  bool _isBotReplying = false;

  // StringBuffer 和 Timer 保持不变，用于平滑更新UI
  final StringBuffer _responseBuffer = StringBuffer();
  Timer? _updateTimer;
  static const _updateInterval = Duration(milliseconds: 100);

  // --- API 地址配置 ---
  // 3. 将 ws://.../chat 改为 http://... ，并移除路径，因为路径在连接时指定
  static const String _host = '198.168.50.140' ;
  static final String _serverUrl = 'http://$_host:5000'; // Socket.IO 使用 http/https
  static final Uri _uploadUrl = Uri.parse('http://$_host:5000/upload');

  // --- 公共 Getter ---
  List<ChatMessage> get messages => _messages;
  bool get isConnecting => _isConnecting;
  bool get isBotReplying => _isBotReplying;


  /// 初始化并连接到 Socket.IO 服务器
  void connect() {
    // 如果已经连接或正在连接，则不执行任何操作
    if (_socket?.connected ?? false || _isConnecting) return;

    _isConnecting = true;
    _addSystemMessage("正在连接服务器...");
    notifyListeners();

    try {
      // 4. 创建 Socket.IO 客户端实例，并指定要连接的命名空间 '/chat'
      _socket = IO.io('$_serverUrl/chat', <String, dynamic>{
        'transports': ['websocket'], // 强制使用 WebSocket 传输
        'autoConnect': false,        // 我们手动调用 connect()
      });

      // 5. 注册事件监听器
      _registerEventListeners();

      // 6. 手动发起连接
      _socket!.connect();

    } catch (e) {
      _isConnecting = false;
      _addSystemMessage("连接失败: $e");
      notifyListeners();
    }
  }
  
  void _registerEventListeners() {
    // 监听连接成功事件
    _socket!.onConnect((_) {
      _isConnecting = false;
      _updateSystemMessage("连接成功！");
      print('ChatService: Connected to /chat namespace');
      notifyListeners();
    });

    // 监听服务器发送的状态消息
    _socket!.on('status', (data) {
      if (data is Map && data.containsKey('message')) {
        _updateSystemMessage(data['message']);
        notifyListeners();
      }
    });

    // 监听大模型返回的数据块
    _socket!.on('new_chunk', (data) {
      if (data is String) {
        _handleServerChunk(data);
      }
    });

    // 监听流结束事件
    _socket!.on('stream_end', (_) {
      _handleStreamEnd();
    });

    // 监听错误事件
    _socket!.on('error', (data) {
      _isBotReplying = false;
      _updateSystemMessage("服务器错误: $data");
      notifyListeners();
    });
    
    // 监听连接错误
    _socket!.onConnectError((err) {
      _isConnecting = false;
      _addSystemMessage("连接错误: $err");
      notifyListeners();
    });

    // 监听断开连接事件
    _socket!.onDisconnect((_) {
      _isBotReplying = false;
      _addSystemMessage("服务器连接已断开。");
      notifyListeners();
    });
  }


  /// 发送消息（文本和/或图片）
  Future<void> sendMessage(String text, {XFile? imageFile}) async {
    // 7. 检查 socket 是否已连接
    if ((text.isEmpty && imageFile == null) || _isBotReplying || !(_socket?.connected ?? false)) {
        if (!(_socket?.connected ?? false)) {
            _addSystemMessage("[错误] 未连接到服务器，请重新连接。");
            notifyListeners();
        }
        return;
    }
    
    // UI 更新逻辑保持不变
    _isBotReplying = true;
    _messages.add(ChatMessage(text: text, isUser: true, imageUrl: null)); // 暂时不处理图片
    _messages.add(ChatMessage(text: "", isUser: false)); // 为机器人回复创建占位符
    notifyListeners();
    
    // 8. 使用 emit 发送带有事件名称的消息
    // (注意：当前后端聊天逻辑未处理图片，这里暂时只发送文本)
    _socket!.emit('send_message', text);
  }

  // --- 消息处理逻辑重构 ---
  void _handleServerChunk(String chunk) {
    _responseBuffer.write(chunk);
    // 启动或保持计时器，以平滑地更新UI
    _updateTimer ??= Timer.periodic(_updateInterval, (_) => _flushBufferToUI());
  }

  void _handleStreamEnd() {
    _updateTimer?.cancel();
    _updateTimer = null;
    // 确保所有剩余的缓冲内容都被刷新到UI
    if (_responseBuffer.isNotEmpty) {
      _flushBufferToUI();
    }
    _isBotReplying = false;
    notifyListeners();
  }

  void _flushBufferToUI() {
    if (_responseBuffer.isEmpty) {
      _updateTimer?.cancel();
      _updateTimer = null;
      return;
    }

    if (_messages.isNotEmpty && !_messages.last.isUser) {
      final lastMessage = _messages.last;
      final updatedMessage = lastMessage.copyWith(
        text: lastMessage.text + _responseBuffer.toString(),
      );
      _messages[_messages.length - 1] = updatedMessage;
      _responseBuffer.clear();
      notifyListeners();
    }
  }

  // 图片上传逻辑保持不变 (但请注意，当前后端聊天逻辑未集成图片处理)
  Future<String?> _uploadImage(XFile imageFile) async {
    // ... (此部分代码完全不变) ...
    var request = http.MultipartRequest('POST', _uploadUrl);
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
      contentType: MediaType('image', imageFile.path.split('.').last),
    ));
    var response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      return jsonDecode(respStr)['file_url'];
    }
    return null;
  }
  
  // 系统消息辅助方法保持不变
  void _addSystemMessage(String text) {
    _messages.add(ChatMessage(text: text, isUser: false));
  }

  void _updateSystemMessage(String text) {
    if (_messages.isNotEmpty && !_messages.last.isUser) {
       _messages.last = _messages.last.copyWith(text: text);
    } else {
       _addSystemMessage(text);
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    // 9. 关闭 Socket.IO 连接
    _socket?.dispose(); 
    super.dispose();
  }
}