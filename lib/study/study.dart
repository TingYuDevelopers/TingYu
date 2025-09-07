import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class StudyPage extends StatefulWidget {
  const StudyPage({super.key});

  @override
  _StudyPageState createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  
  final channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8765'),
    );
  VideoPlayerController? _controller;
  double progressValue = 0.0;

  @override
  void initState() {
    super.initState();
    channel.stream.listen((videomessage)async{
      if (videomessage is String && videomessage.startsWith('PROGRESS')){
        final progress = videomessage.split(':')[1];
        progressValue = double.tryParse(progress) ?? 0.0;
        print('视频生成进度: $progress%');
      }else if (videomessage == "DONE"){
        final url = 'http://localhost:7860/$videomessage';
        final response = await http.get(Uri.parse(url));
        final file = File('/local/path/video.mp4');
        await file.writeAsBytes(response.bodyBytes);
        setState((){
          _controller = VideoPlayerController.file(file)..initialize();
        });
      }else if (videomessage is List<int>){
        final file = File('/local/path/video.mp4');
        await file.writeAsBytes(videomessage);
        setState((){
          _controller = VideoPlayerController.file(file)..initialize();
        });
      };
    });
  }

  

  @override
  Widget build(BuildContext context) {
    print('StudyPage 正在构建');
    return Scaffold(
      appBar: AppBar(
        title: Text('唇语学习视频'),
      ),
      body: Center(
        child:(_controller!=null&&_controller!.value.isInitialized)
        ?AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          //使用stack来叠加视频和控制按钮
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              //视频播放器
              VideoPlayer(_controller!),
              //播放/暂停按钮
              _buildControls(),
            ],
          )
        ):const CircularProgressIndicator(),
      ),
    );
  }
  Widget _buildControls(){
    if (_controller == null || (progressValue/100) < 1.0){
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: LinearProgressIndicator(
          value: null,
          backgroundColor: Colors.grey,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    }else{
      return GestureDetector(
        onTap: (){
          setState((){
            _controller!.value.isPlaying?_controller!.pause():_controller!.play();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.deepOrangeAccent.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _controller!.value.isPlaying?Icons.pause : Icons.play_arrow,
            color : Colors.white,
            size: 80.0,
          ),
        ),
      );
    }
  }
 
  @override
  void dispose() {
    super.dispose();
    channel.sink.close();
    _controller?.dispose();
  }
}