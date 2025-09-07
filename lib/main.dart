// 库
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http; // http客户端用于网络请求
import 'dart:io' as io; // 文件操作，重命名为io以避免冲突
import 'package:flutter/services.dart'; // 顶部已导入
// 引入其他页面
import 'package:my_app/word_puzzle/word_puzzle_page.dart'; // 拼字游戏页面
import 'AiChat/ChatScreen.dart'; // AI聊天页面
import 'AiChat/ChatService.dart'; // AI聊天服务
import 'study/study.dart'; // 唇语学习页面
import 'conversation/conversation_audio.dart'; // 对话音频页面 (如果这个页面是你想要的第三个按钮功能)

// import 'dart:html' as html; // 仅在 Web 环境下使用
// 应用入口函数
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ChatService(),
      child: const MyApp(),
    ),
  );
}

// 主应用组件
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZhuiYu-听障康复软件',
      theme: ThemeData(
        primarySwatch: Colors.orange, // 橙色，可改
        useMaterial3: true,
        scaffoldBackgroundColor: Color(0xFFFFF0E0),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFFFA07A), // 浅红
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFE57373),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            textStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      home: const MainMenuPage(),
    );
  }
}

// 新的单一初始页面
class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  _MainMenuPageState createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String? _videoFilePath;
  bool _isRecorderReady = false;
  String? _errorMessage;
  late VideoPlayerController _videoPlayerController;
  bool _isVideoInitialized = false;
  String? _audioFilePath; // 添加音频文件路径变量

  @override
  void initState() {
    super.initState();
    _initRecorder();
    // 视频播放器初始化不再在initState中强制调用，只在_videoFilePath有值时调用
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    if (_isVideoInitialized) {
      _videoPlayerController.dispose();
    }
    super.dispose();
  }

  // 上传图片的方法
  Future<void> uploadImage(XFile imageFile) async {
    // 图片上传逻辑，需要根据实际后端和环境调整
    // 如果是Web环境，需要使用dart:html，但这里为了跨平台兼容性，暂时注释了Web特有的部分
    if (kIsWeb) {
      // final bytes = await imageFile.readAsBytes();
      // final blob = html.Blob([bytes]);
      // final formData = html.FormData();
      // formData.appendBlob('image', blob, imageFile.name);
      // final response = await html.HttpRequest.request(
      //   'http://192.168.233.1:5000/api/upload/image',
      //   method: 'POST',
      //   sendData: formData,
      // );
      // if (response.status == 200) {
      //   print('图片上传成功');
      // } else {
      //   print('图片上传失败: ${response.status}');
      // }
      print('Web环境下图片上传功能未完全实现或依赖html库。');
    } else {
      final url = Uri.parse('http://192.168.233.1:5000/api/upload/image');
      try {
        final request = http.MultipartRequest('POST', url);
        final file = await http.MultipartFile.fromPath('image', imageFile.path);
        request.files.add(file);
        final response = await request.send();
        if (response.statusCode == 200) {
          print('图片上传成功');
        } else {
          print('图片上传失败: ${response.statusCode}');
        }
      } catch (e) {
        setState(() {
          _errorMessage = '图片上传错误：$e';
        });
        print('图片上传错误：$e');
      }
    }
  }

  // 上传音频的方法
  Future<void> uploadAudio(String audioFilePath) async {
    final url = Uri.parse('http://192.168.233.1:5000/api/upload/audio');
    try {
      final request = http.MultipartRequest('POST', url);
      final file = await http.MultipartFile.fromPath('audio', audioFilePath);
      request.files.add(file);

      final response = await request.send();
      if (response.statusCode == 200) {
        print('音频上传成功');
      } else {
        throw Exception('音频上传错误');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '音频上传失败: ${e.toString()}';
      });
      print('音频上传失败：$e');
    }
  }

  // 初始化视频播放器
  Future<void> _initializeVideoPlayer() async {
    if (_videoFilePath != null) {
      try {
        if (_isVideoInitialized) {
          await _videoPlayerController.pause();
          await _videoPlayerController.dispose();
        }

        _videoPlayerController =
            VideoPlayerController.file(io.File(_videoFilePath!));
        await _videoPlayerController.initialize();

        setState(() {
          _isVideoInitialized = true;
        });
      } catch (e) {
        print('视频初始化失败: $e');
        setState(() {
          _isVideoInitialized = false;
          _videoFilePath = null;
        });
      }
    } else {
      setState(() {
        _isVideoInitialized = false;
      });
    }
  }

  // 初始化录音器并请求权限
  Future<void> _initRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        // 不在这里设置 _errorMessage，避免页面一打开就显示
        // setState(() {
        //   _errorMessage = '需要麦克风权限才能录音';
        // });
      } else {
        await _recorder.openRecorder();
        setState(() {
          _isRecorderReady = true;
        });
      }
    } catch (e) {
      // 不在这里设置 _errorMessage，避免页面一打开就显示
      // setState(() {
      //   _errorMessage = '录音初始化失败: ${e.toString()}';
      // });
      print('录音初始化错误: $e');
    }
  }

  // 开始/停止录音
  Future<void> _toggleRecording() async {
    if (!_isRecorderReady) {
      setState(() {
        _errorMessage = '录音器未准备好，请稍候';
      });
      return;
    }

    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }

    try {
      if (_isRecording) {
        await _recorder.stopRecorder();
        setState(() => _isRecording = false);
        if (_audioFilePath != null) {
          uploadAudio(_audioFilePath!);
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        _audioFilePath = '${directory.path}/recording.wav';
        await _recorder.startRecorder(toFile: _audioFilePath);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '录音操作失败: ${e.toString()}';
        _isRecording = false;
      });
      print('录音错误: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用 MediaQuery 获取屏幕宽度和高度，用于响应式布局
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround, // 将内容均匀分布
          children: [
            SizedBox(height: 30), // 顶部留白
            Column(
              children: [
                Image.asset(
                  'assets/Wechat.jpg', // Logo图片路径（已修改）
                  width: screenWidth * 0.25,
                  height: screenWidth * 0.25,
                ),
                SizedBox(height: 20),
                Text(
                  '缀语精灵',
                  style: TextStyle(
                    fontSize: screenWidth * 0.06, // 字体大小响应式
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B4513),
                  ),
                ),
              ],
            ),

            // 三个功能按钮，横向一字排开
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 按钮均匀分布
                children: [
                  Flexible(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ChatPage()),
                        );
                      },
                      child: Text('小树洞'),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03), // 按钮间距响应式
                  Flexible(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () async {
                        final status = await Permission.camera.request();
                        if (status != PermissionStatus.granted) {
                          setState(() {
                            _errorMessage = '需要相机权限才能拍照';
                          });
                          return;
                        }
                        final picker = ImagePicker();
                        final pickedFile =
                            await picker.pickImage(source: ImageSource.camera);
                        if (pickedFile != null) {
                          uploadImage(pickedFile);
                        } else {
                          print('No image selected.');
                        }
                      },
                      child: Text('小眼睛'),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03), // 按钮间距响应式
                  Flexible(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => StudyPage()),
                        );
                      },
                      child: Text('学习'),
                    ),
                  ),
                ],
              ),
            ),

            // 录音和退出按钮
            Column(
              children: [
                // 录音波纹
                if (_isRecording)
                  Image.asset(
                    'assets/ba.png', // 假设 ba.png 是波纹动画
                    width: screenWidth * 0.15, // 波纹尺寸响应式
                    height: screenWidth * 0.15,
                  ),
                SizedBox(height: 10),

                // 错误提示
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                          color: Color(0xFFD32F2F), fontSize: 14), // 红色
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center, // 居中
                  children: [
                    // 录音按钮
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/ac.png', // 麦克风图标
                            width: screenWidth * 0.18,
                            height: screenWidth * 0.18,
                          ),
                          if (_isRecording)
                            Container(
                              width: screenWidth * 0.04,
                              height: screenWidth * 0.04,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30), // 底部留白
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 辅助方法，用于构建特色功能按钮
  Widget _buildFeatureButton(
    BuildContext context, {
    required String iconPath,
    required double screenWidth,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          // 使用InkWell提供点击反馈
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: EdgeInsets.all(screenWidth * 0.02), // 填充响应式
            decoration: BoxDecoration(
              color: Color(0xFFFFCC80), // 浅橙色
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Image.asset(
              iconPath,
              width: screenWidth * 0.15, // 图标尺寸响应式
              height: screenWidth * 0.15,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFD2691E), //棕色
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.035, // 文本尺寸响应式
          ),
        ),
      ],
    );
  }
}
