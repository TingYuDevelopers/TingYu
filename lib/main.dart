// 库
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;//hhtp客户端用于网络请求
import 'dart:io';//文件操作
import 'package:my_app/word_puzzle/word_puzzle_page.dart';
import 'package:video_player/video_player.dart'; // 引入视频播放库
import 'AiChat/ChatScreen.dart';
import 'dart:html' as html;

// 应用入口函数
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

// 主应用组件
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我的应用',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainPage(), 
    );
  }
}

// 主页组件
class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // 设置背景图片
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icon.png',
                    width: 100,
                    height: 100,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Owl_Talk',
                    style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 50),

                  // 开始按钮 - 导航到目录页面
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => MenuPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text('快来学习吧'),
                  ),
                  
                  // 新增拼字游戏按钮
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => WordPuzzlePage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text('拼字游戏'),
                  ),
                  SizedBox(height: 20),
                  
                  // 退出按钮 - 返回主页
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text('再见喽，欢迎经常来玩呀'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}




// 导入录音和权限相关包

// 目录页面组件 - 转换为StatefulWidget以支持录音状态管理
class MenuPage extends StatefulWidget {
  const MenuPage({Key? key}) : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}


class _MenuPageState extends State<MenuPage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String? _videoFilePath;
  final String _dialogText = "按住话筒,\n来聊天吧!";
  final bool _isDialogVisible = true;
  bool _isRecorderReady = false;
  String? _errorMessage;
  late VideoPlayerController _videoPlayerController;
  final bool _isPlaying = false;
  bool _isVideoInitialized = false;
  String? _audioFilePath; // 添加音频文件路径变量
  final bool _isChatting = false;

  @override
  void initState() {
    super.initState();
    _initRecorder(); // 添加初始化调用
    _initializeVideoPlayer(); // 添加视频播放器初始化
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    if (_isVideoInitialized) {
      _videoPlayerController.dispose();
    }
    super.dispose();
  }
  //上传图片的方法
  Future<void> uploadImage(XFile imageFile) async {
    if (kIsWeb) { // 检查是否为 Web 环境
      final bytes = await imageFile.readAsBytes();
      final blob = html.Blob([bytes]);
      final formData = html.FormData();
      formData.appendBlob('image', blob, imageFile.name);

      final response = await html.HttpRequest.request(
        'http://192.168.50.141:5000/api/upload/image',
        method: 'POST',
        sendData: formData,
      );
      if (response.status == 200) {
        print('图片上传成功');
      } else {
        print('图片上传失败: ${response.status}');
      }
    } else { // 非 Web 环境
      final url = Uri.parse('http://192.168.50.141:5000/api/upload/image');
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
  //上传音频的方法
  Future<void> uploadAudio(String audioFilePath) async {
    final url = Uri.parse('http://192.168.50.141:5000/api/upload/audio');
    try {
      final request = http.MultipartRequest('POST', url);
      final file = await http.MultipartFile.fromPath('audio', audioFilePath);
      request.files.add(file);

      final response = await request.send();
      if (response.statusCode == 200){
        print('音频上传成功');
      }else{
        throw Exception('音频上传错误');
      }
    }catch (e) {
      setState((){
        _errorMessage = '音频上传失败: ${e.toString()}';
      });
      print('音频上传失败：$e');
    }
  }
  //抓取视频文件
  Future<void> downloadFile(String filename) async {
    var url = 'http://192.168.50.141:5000/api/receive-video/$filename';
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String savePath = '${appDocDir.path}/$filename';
      File file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);
      print('File saved to: $savePath');

      setState(() {
        if (filename.endsWith('.mp4') || filename.endsWith('.avi')) {
          _videoFilePath = savePath;
          _initializeVideoPlayer(); // 初始化视频播放器
        } else if (filename.endsWith('.wav') || filename.endsWith('.mp3')) {
          _audioFilePath = savePath;
        }
      });
    } else {
      throw Exception('Download failed: ${response.statusCode}');
    }
  }
  File XfileConvertToFile(XFile XFile){
    return File(XFile.path);
  }

  //抓取唇语视频
  Future<void> generateLipSync(String sentence, String videoPath) async {
    var url = Uri.parse('http://192.168.50.141:5000/api/generate-lipsync');
    var response = await http.post(url, headers:{'Content-Type':'application/json'},body: jsonEncode({
      'sentence': sentence,
      'video_path':videoPath,
    }));
    if (response.statusCode == 200){
      print('唇语生成成功');
      var responseData = jsonDecode(response.body);
      print('视频路径：${responseData['video_path']}');
    }else{
      print('唇语生成失败');
    }
  }
  //初始化视频播放器
  Future<void> _initializeVideoPlayer() async {
    if (_videoFilePath != null) {
      try {
        // 释放旧的控制器资源
        await _videoPlayerController.pause();
        await _videoPlayerController.dispose();
        
        // 创建新的控制器实例
        _videoPlayerController = VideoPlayerController.file(File(_videoFilePath!));
        
        // 初始化视频
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
        setState(() {
          _errorMessage = '需要麦克风权限才能录音';
        });
      } else {
        await _recorder.openRecorder();
        setState(() {
          _isRecorderReady = true;
        });
      }
    } catch (e) {
        setState(() {
          _errorMessage = '录音初始化失败: ${e.toString()}';
        }
      );
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
        // 录音完成后的处理逻辑
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
    try {
      return Scaffold(
        appBar: AppBar(
          title: Text('目录页面'),
        ),
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.25,
                    bottom: MediaQuery.of(context).size.height * 0.25,
                    right: MediaQuery.of(context).size.width / 6,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 交流按钮
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () async{
                                // 交流功能
                                Navigator.push(
                                  context, 
                                MaterialPageRoute(builder: (context) => ChatScreen()),
                              );
                            },
                            child: Image.asset('assets/Group 222.png', width: 80, height: 80),
                          ),
                          SizedBox(height: 8),
                          Text('交流'),
                        ],
                      ),
                      SizedBox(height: 30),
                      // 拍照按钮（中间按钮向右偏移）
                      Padding(
                        padding: EdgeInsets.only(left: 30),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final picker = ImagePicker();
                                final pickedFile = await picker.pickImage(source: ImageSource.camera);
                                if (pickedFile != null) {
                                  uploadImage(pickedFile);// 处理拍照
                                } else {
                                  print('No image selected.');
                                }
                              },
                              child: Image.asset('assets/Group 227.png', width: 80, height: 80),
                            ),
                            SizedBox(height: 8),
                            Text('拍照'),
                          ],
                        ),
                      ),
                      SizedBox(height: 30),
                      // 学习按钮
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              // 学习功能待实现
                              Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => WordPuzzlePage()),
                            );
                            },
                            child: Image.asset('assets/Group 228.png', width: 80, height: 80),
                          ),
                          SizedBox(height: 8),
                          Text('学习'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // 迁移的aa.png和ab.png图片
              Positioned(
                left: 150,
                top: MediaQuery.of(context).size.height * 0.7,
                child: Row(
                  children: [
                    Image.asset('assets/aa.png', width: 60, height: 60),
                    SizedBox(width: 15),
                    Image.asset('assets/ab.png', width: 60, height: 60),
                  ],
                ),
              ),
              // 录音按钮上方显示ba.png
              if (_isRecording)
                Positioned(
                  left: MediaQuery.of(context).size.width * 0.5 - 67.5,
                  top: MediaQuery.of(context).size.height * 0.8 - 90, // 位于录音按钮上方
                  child: Image.asset('assets/ba.png', width: 80, height: 80),
                ),
              // 中间下部分放置ac.png(录音按钮)和ad.png(退出按钮)
              Positioned(
                left: MediaQuery.of(context).size.width * 0.5 - 67.5,
                top: MediaQuery.of(context).size.height * 0.8,
                child: Row(
                  children: [
                    // 录音按钮(ac.png)
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset('assets/ac.png', width: 80, height: 80),
                          if (_isRecording) // 录音状态指示器
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          // 错误提示
                          if (_errorMessage != null)
                            Positioned(
                              bottom: -30,
                              left: 0,
                              right: 0,
                              child: Text(
                                _errorMessage!, 
                                style: TextStyle(color: Colors.red, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 15),
                    // 退出按钮(ad.png)
                    GestureDetector(
                      onTap: () => Navigator.pop(context), // 返回主页
                      child: Image.asset('assets/ad.png', width: 80, height: 80),
                    ),
                  ],
                ),
              ),
              // 左上角三分之一区域放置icon2.png
              Positioned(
                left: 100,
                top: 100,
                width: MediaQuery.of(context).size.width / 4,
                height: MediaQuery.of(context).size.height / 3,
                child: Image.asset('assets/icon2.png', fit: BoxFit.contain),
              ),
              // 动态对话框 - 聊天气泡效果
              if (_isDialogVisible)
                Positioned(
                  left: 80 + MediaQuery.of(context).size.width / 4 + 10,
                  top: 100,
                  child: Stack(
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width / 3,
                        ),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          _dialogText,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // 聊天气泡三角形指向
                      Positioned(
                        left: -10,
                        top: 20,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          transform: Matrix4.rotationZ(45 * 3.1415926535 / 180),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      // 处理播放器操作中的异常
      print('视频播放器操作错误：$e');
      setState(() {
        _errorMessage = '视频操作失败: ${e.toString()}';
      });
      return Container(); // 添加默认返回值
    }
  }
}
