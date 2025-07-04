import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class ChatService {
  late IO.Socket socket;
  final _responseController = StreamController<Map<String, dynamic>>();

  ChatService() {
    // 创建 Socket.IO 连接
    socket = IO.io(
      'http://192.168.50.141:5000',
      IO.OptionBuilder()
        .setTransports(['websocket']) // 强制使用 WebSocket
        .enableAutoConnect()          // 自动连接
        .setQuery({'EIO': '4'})       // 指定协议版本
        .build(),
    );

    // 添加基础事件监听
    socket.onConnect((_) => print('已连接到服务器'));
    socket.onDisconnect((_) => print('已断开连接'));
    socket.onError((error) => print('连接错误: $error'));

    // 初始化 server_response 监听
    socket.on('server_response', (data) {
      if (data is Map<String, dynamic>) {
        _responseController.add(data);
      } else {
        _responseController.add({'error': '无效的响应格式'});
      }
    });
  }

  void sendMessage(String message, List<dynamic> history) {
    // 使用 Socket.IO 的 emit 方法发送消息
    socket.emit('user_message', {
      'message': message,
      'history': history,
    });
  }

  Stream<Map<String, dynamic>> get responses {
    return _responseController.stream;
  }

  void dispose() {
    socket.disconnect(); // 断开连接
    _responseController.close(); // 关闭流
  }
}

