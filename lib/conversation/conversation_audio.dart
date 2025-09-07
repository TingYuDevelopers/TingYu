import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:web_socket_channel/io.dart';

// 导入主页面
import '../main.dart';

class ConversationAudio extends StatefulWidget {
  const ConversationAudio({super.key});

  @override
  _ConversationAudioState createState() => _ConversationAudioState();
}

class _ConversationAudioState extends State<ConversationAudio> {
  static String _serverUrl = Uri.parse('ws://192.168.50.140:7860/ws').toString(); // ❗️注意这里
  IO.Socket? _socket;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecorderInitialized = false;
  StreamController<Uint8List>? _recordingStreamController;
  StreamSubscription? _recorderSubscription;

  String _status = "状态就绪";
  bool _isRecording = false;
  void connectWebSocket() {
  IOWebSocketChannel? channel;
  try {
    // 替换成你的后端地址
    final wsUrl = Uri.parse('ws://192.168.50.140:7860/ws'); // ❗️注意这里
      channel = IOWebSocketChannel.connect(wsUrl);

      print("正在尝试连接到: $wsUrl");

      channel.stream.listen(
        (message) {
          // 成功接收到消息
          print("收到消息: $message");
        },
        onDone: () {
          // 连接已关闭
          print("WebSocket 连接已关闭");
        },
        onError: (error) {
          // ❗️❗️❗️ 关键：捕获并打印具体的错误信息 ❗️❗️❗️
          print("WebSocket 发生错误: $error");
          // 例如，这里可能会打印 "Connection refused" (连接被拒绝)
          // 或者 "SocketException: OS Error: Connection timed out" (连接超时)
        },
      );
    } catch (e) {
      // 这个 catch 块可能不会捕获到所有连接错误，因为连接是异步的
      // 但加上总没错
      print("连接时发生异常: $e");
    }
  }
  @override
  void initState() {
    super.initState();
    _recorder.openRecorder().then((value) {
      setState(() {
        _isRecorderInitialized = true;
      });
    });
    _requestPermissions();
    _connectSocketIO();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  void _connectSocketIO() {
    if (_socket?.connected ?? false) return;
    try {
      _socket = IO.io(_serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });
      _registerEventListeners();
      _socket!.connect();
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = "连接失败: $e";
        });
      }
    }
  }

  void _registerEventListeners() {
    _socket!.onConnect((_) {
      if (mounted) {
        setState(() {
          _status = "已连接，可以开始讲话";
        });
      }
    });
    _socket!.on('audio_response', (data) {
      if (data is List<int>) {
        if (mounted) {
          setState(() {
            _status = "正在播放回复";
          });
          _playAudioResponse(Uint8List.fromList(data));
        }
      }
    });
    _socket!.on('status', (data) {
      if (data is String) {
        if (mounted) {
          setState(() {
            _status = data;
          });
        }
      }
    });
    _socket!.onConnectError((error) {
      if (mounted) {
        setState(() {
          _status = "连接错误: $error";
        });
        _reconnect();
      }
    });
    _socket!.onDisconnect((_) {
      if (mounted) {
        setState(() {
          _status = "已断开";
        });
        _reconnect();
      }
    });
  }

  void _reconnect() {
    if (mounted) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _connectSocketIO();
        }
      });
    }
  }

  Future<void> _startStreaming() async {
    if (!_isRecorderInitialized ||
        !(_socket?.connected ?? false) ||
        _recorder.isRecording) {
      return;
    }
    _recordingStreamController = StreamController<Uint8List>();
    _recorderSubscription = _recordingStreamController!.stream.listen((data) {
      _socket!.emit('audio_stream', data);
    });
    await _recorder.startRecorder(
      toStream: _recordingStreamController!.sink,
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
    );
    if (mounted) {
      setState(() {
        _isRecording = true;
        _status = "正在录音...";
      });
    }
  }

  Future<void> _stopStreaming() async {
    if (!_recorder.isRecording) return;
    await _recorder.stopRecorder();
    if (_recorderSubscription != null) {
      await _recorderSubscription!.cancel();
      _recorderSubscription = null;
    }
    if (_recordingStreamController != null) {
      await _recordingStreamController!.close();
      _recordingStreamController = null;
    }
    _socket!.emit('message', 'END_OF_STREAM');
    if (mounted) {
      setState(() {
        _isRecording = false;
        _status = "正在处理";
      });
    }
  }

  Future<void> _playAudioResponse(Uint8List audioData) async {
    try {
      final source = BytesAudioSource(audioData);
      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.play();
      _audioPlayer.playerStateStream
          .firstWhere(
              (state) => state.processingState == ProcessingState.completed)
          .then((_) {
        if (mounted) {
          setState(() {
            _status = "已连接，请按住按钮说话";
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = "播放错误: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _recorderSubscription?.cancel();
    _recordingStreamController?.close();
    _recorder.closeRecorder();
    _socket?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // 新增：功能不可用时自动跳转并弹框
    if (!_isRecorderInitialized || !(_socket?.connected ?? false)) {
      Future.microtask(() {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainMenuPage()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('暂时无法使用'),
            duration: Duration(seconds: 2),
          ),
        );
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: const Text("缀语精灵聊天")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(_status,
                  style: const TextStyle(fontSize: 15),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 50),
            GestureDetector(
              onLongPressStart: (_) => _startStreaming(),
              onLongPressEnd: (_) => _stopStreaming(),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color:
                      _isRecording ? Colors.red.shade700 : Colors.blue.shade700,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black.withOpacity(0.3),
                    )
                  ],
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 60),
              ),
            ),
            const SizedBox(height: 20),
            const Text("按住说话", style: TextStyle(color: Colors.grey)),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Image.asset(
                'assets/ad.png',
                width: screenWidth * 0.18,
                height: screenWidth * 0.18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// BytesAudioSource 辅助类保持不变
class BytesAudioSource extends StreamAudioSource {
  final Uint8List _buffer;

  BytesAudioSource(this._buffer) : super(tag: 'BytesAudioSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _buffer.length;
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_buffer.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
