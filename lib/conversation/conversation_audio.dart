import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
// 1. 导入 socket_io_client
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:async';

class ConversationAudio extends StatefulWidget {
  const ConversationAudio({super.key});

  @override
  _ConversationAudioState createState() => _ConversationAudioState();
}

class _ConversationAudioState extends State<ConversationAudio> {
  // 2. 更改 URL 格式并移除 WebSocket 相关的 channel
  static const String _serverUrl = "http://localhost:5000"; // 使用 http/https
  IO.Socket? _socket;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecorderInitialized = false;
  StreamController<Uint8List>? _recordingStreamController;
  StreamSubscription? _recorderSubscription;


  String _status = "状态就绪";
  bool _isRecording = false;

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

  // 3. 重写连接逻辑以使用 Socket.IO
  //确保这些事件名 (audio_response, status) 与您后端 emit() 时使用的事件名完全一致。
  void _connectSocketIO() {
    // 如果已连接，则无需操作
    if (_socket?.connected ?? false) return;

    try {
      // 创建 Socket.IO 实例，连接到默认命名空间
      _socket = IO.io(_serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      _registerEventListeners(); // 注册事件监听
      _socket!.connect(); // 手动连接

    } catch (e) {
      if (mounted) {
        setState(() {
          _status = "连接失败: $e";
        });
      }
    }
  }

  void _registerEventListeners() {
    // 监听连接成功
    _socket!.onConnect((_) {
      if (mounted) {
        setState(() {
          _status = "已连接，可以开始讲话";
        });
        print("Socket.IO connected!");
      }
    });

    // 监听服务器返回的音频数据 (事件名应与后端一致，例如 'audio_response')
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
    
    // 监听服务器返回的文本状态消息 (事件名应与后端一致，例如 'status')
    _socket!.on('status', (data) {
      if (data is String) {
        if (mounted) {
          setState(() {
            _status = data;
          });
        }
      }
    });

    // 监听连接错误
    _socket!.onConnectError((error) {
       if (mounted) {
        setState(() {
          _status = "连接错误: $error";
        });
        _reconnect();
      }
    });

    // 监听断开连接
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
      // 避免在销毁的 widget 上调用 setState
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _connectSocketIO();
        }
      });
    }
  }

    Future<void> _startStreaming() async {
  if (!_isRecorderInitialized || !(_socket?.connected ?? false) || _recorder.isRecording) {
    return;
  }

  // 1. 创建一个【直接处理 Uint8List】的管道
  _recordingStreamController = StreamController<Uint8List>();

  // 2. 监听这个管道的出口，参数 `data` 直接就是 Uint8List
  _recorderSubscription = _recordingStreamController!.stream.listen((data) {
    // 无需再访问 .data 属性，因为 `data` 本身就是我们需要的音频数据块
    _socket!.emit('audio_stream', data);
  });

  // 3. 开始录音，flutter_sound 会将原始的 Uint8List 数据块直接放入 sink
  await _recorder.startRecorder(
    toStream: _recordingStreamController!.sink, // 连接到我们的管道入口
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

    // 【重要】关闭监听和管道，释放资源
    if (_recorderSubscription != null) {
      await _recorderSubscription!.cancel();
      _recorderSubscription = null;
    }
    if (_recordingStreamController != null) {
      await _recordingStreamController!.close();
      _recordingStreamController = null;
    }

    // 发送结束信号
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

      // 监听播放完成
      _audioPlayer.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed
      ).then((_) {
        if (mounted) {
          setState(() {
            _status = "已连接，请按住按钮说话";
          });
        }
      });
    } catch (e) {
        if (mounted) {
            setState(() { _status = "播放错误: $e"; });
        }
    }
  }

  @override
  void dispose() {
    // 确保所有资源都被释放
    _recorderSubscription?.cancel();
    _recordingStreamController?.close();
    _recorder.closeRecorder();
    _socket?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("缀语精灵聊天")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(_status, style: const TextStyle(fontSize: 15), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 50),
            GestureDetector(
              onLongPressStart: (_) => _startStreaming(),
              onLongPressEnd: (_) => _stopStreaming(),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red.shade700 : Colors.blue.shade700,
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
            const Text("按住说话", style: TextStyle(color: Colors.grey)), // 改个更清晰的颜色
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