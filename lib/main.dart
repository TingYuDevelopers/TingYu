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
import 'package:http/http.dart' as http;//http客户端用于网络请求
import 'dart:io' as io;//文件操作，重命名为io以避免冲突
import 'package:my_app/word_puzzle/word_puzzle_page.dart';
// 引入视频播放库
import 'AiChat/ChatScreen.dart';
import 'AiChat/ChatService.dart';
import 'dart:html' as html;
import 'study/study.dart';
import 'conversation/conversation_audio.dart';

// 应用入口函数
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ChatService(),
      child: const MyApp(), 
    ),
  );
}

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     // 现在，MyApp 和它的所有子 Widget (包括 MaterialApp 和 ChatPage)
//     // 都在 ChangeNotifierProvider 的“下方”，因此可以安全地访问 ChatService。
//     return MaterialApp(
//       title: 'ZhuiYu-听障康复软件',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         useMaterial3: true,
//       ),
//       home: const ChatPage(), // 你的聊天页面
//     );
//   }
// }
// 主应用组件
class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
  const MainPage({super.key});

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
                    '缀语精灵',
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
  const MenuPage({super.key});

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
        'http://192.168.233.1:5000/api/upload/image',
        method: 'POST',
        sendData: formData,
      );
      if (response.status == 200) {
        print('图片上传成功');
      } else {
        print('图片上传失败: ${response.status}');
      }
    } else { // 非 Web 环境
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
  //上传音频的方法
  Future<void> uploadAudio(String audioFilePath) async {
    final url = Uri.parse('http://192.168.233.1:5000/api/upload/audio');
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
    var url = 'http://192.168.233.1:5000/api/receive-video/$filename';
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      io.Directory appDocDir = await getApplicationDocumentsDirectory();
      String savePath = '${appDocDir.path}/$filename';
      io.File file = io.File(savePath);
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
  io.File XfileConvertToFile(XFile XFile){
    return io.File(XFile.path);
  }

  //抓取唇语视频
  Future<void> generateLipSync(String sentence, String videoPath) async {
    var url = Uri.parse('http://192.168.233.1:5000/api/generate-lipsync');
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
        _videoPlayerController = VideoPlayerController.file(io.File(_videoFilePath!));
        
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
  // 使用 MediaQuery.of(context) 来获取一次屏幕尺寸，避免在多处重复调用
  final screenSize = MediaQuery.of(context).size;

  return Scaffold(
    appBar: AppBar(
      title: Text('目录页面'),
    ),
    body: Container(
      // 确保背景容器填满整个屏幕
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      // 1. 核心修改：使用 Stack 作为主布局
      child: Stack(
        children: [
          // 2. 右侧的按钮组 (交流、拍照、学习)
          // 使用 Positioned 来精确控制其位置
          Positioned(
            top: screenSize.height * 0.20, // 从顶部 20% 的位置开始
            right: 30, // 距离右边缘 30 像素
            child: Column(
              mainAxisSize: MainAxisSize.min, // 让 Column 的高度自适应内容
              children: [
                // 文本交流按钮
                _buildMenuButton(
                  assetPath: 'assets/Group 222.png',
                  label: 'ZhuiYu小树洞',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ChatPage()),
                    );
                  },
                ),
                // 拍照按钮
                _buildMenuButton(
                  assetPath: 'assets/Group 227.png',
                  label: 'ZhuiYu眼睛',
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.camera);
                    if (pickedFile != null) {
                      // uploadImage(pickedFile);
                    } else {
                      print('No image selected.');
                    }
                  },
                ),
                SizedBox(height: 20),

                // 学习按钮
                _buildMenuButton(
                  assetPath: 'assets/Group 228.png',
                  label: 'ZhuiYu唇语视频学习',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => StudyPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            top:100,
            bottom:100,
            left:200,
            child: Row(
              children:[
                SizedBox(width:30),
                GestureDetector(
                  onTap:(){
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context)=>ConversationAudio()),
                    );
                  },
                  child: Image.asset('assets/icon.png',width:60, height: 80),
                )
              ],
            ),
          ),
          // 3. 左侧中下部的 ab.png 图片
          Positioned(
            left: 30, // 距离左边缘 30
            bottom: screenSize.height * 0.2, // 距离底部 20%
            child: Image.asset('assets/ab.png',width:80,height:80),
          ),

          // 4. 中间底部的录音和退出按钮
          Positioned(
            bottom: 50, // 距离底部 50
            left: 0,
            right: 0, // left: 0, right: 0 会让子组件在水平方向上填满，配合Row的居中非常有效
            child: Column( // 使用 Column 包含录音波纹和按钮行
              mainAxisSize: MainAxisSize.min,
              children: [
                // 录音按钮上方显示 ba.png (波纹)
                if (_isRecording)
                  Image.asset('assets/ba.png', width: 80, height: 80),
                
                SizedBox(height: 10), // 波纹和按钮的间距

                Row(
                  mainAxisAlignment: MainAxisAlignment.center, // 让按钮行水平居中
                  children: [
                    // 录音按钮(ac.png)
                    GestureDetector(
                      onTap: () {}, // _toggleRecording,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset('assets/ac.png', width: 80, height: 80),
                          if (_isRecording)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 40),
                    // 退出按钮(ad.png)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Image.asset('assets/ad.png', width: 80, height: 80),
                    ),
                  ],
                ),
                // 错误提示
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),

          // 5. 左上角的 icon2.png
          Positioned(
            left: 30, // 距离左边缘 30
            top: 30,  // 距离顶部 30 (相对于 body)
            child: Image.asset('assets/icon2.png', width: screenSize.width / 4, fit: BoxFit.contain),
          ),

          // 6. 动态对话框 - 聊天气泡效果
          if (_isDialogVisible)
            Positioned(
              left: 30 + screenSize.width / 4 + 10, // 定位在 icon 右边
              top: 30,
              child: _buildChatBubble(_dialogText), // 将对话框抽成一个辅助方法
            ),
        ],
      ),
    ),
  );
}

// 辅助方法，用于构建菜单按钮，避免代码重复
Widget _buildMenuButton({
  required String assetPath,
  required String label,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(assetPath, width: 70, height: 70), // 统一尺寸
        SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), // 统一文本样式
      ],
    ),
  );
}

// 辅助方法，用于构建聊天气泡，使 build 方法更整洁
Widget _buildChatBubble(String text) {
  // 注意：这个聊天气泡的三角形指向逻辑有些复杂，这里是简化的实现
  return Container(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width / 3,
    ),
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 16, color: Colors.black87),
      ),
    );
  }
}