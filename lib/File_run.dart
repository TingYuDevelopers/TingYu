import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:just_audio/just_audio.dart';
import 'File_utils.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path/path.dart';

class FilePreview extends StatefulWidget {
  final String fileUrl;
  final File? localFile;

  const FilePreview({super.key, required this.fileUrl, this.localFile});

  @override
  _FilePreviewState createState() => _FilePreviewState();
}

class _FilePreviewState extends State<FilePreview> {
  late String _filePath;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    _filePath = widget.localFile?.path ?? widget.fileUrl;
    _initializePlayer();
  }

  void _initializePlayer() {
    if (FileTypeHelper.isVideo(_filePath)) {
      _videoController = widget.localFile != null
          ? VideoPlayerController.file(widget.localFile!)
          : VideoPlayerController.network(widget.fileUrl);
      
      _videoController!.initialize().then((_) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
        );
        setState(() {});
      });
    } else if (FileTypeHelper.isAudio(_filePath)) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.setUrl(widget.fileUrl);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (FileTypeHelper.isImage(_filePath)) {
      return widget.localFile != null
          ? Image.file(widget.localFile!)
          : Image.network(widget.fileUrl);
    } 
    else if (FileTypeHelper.isVideo(_filePath)) {
      if (_chewieController?.videoPlayerController.value.isInitialized ?? false) {
        return Chewie(controller: _chewieController!);
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    } 
    else if (FileTypeHelper.isAudio(_filePath)) {
      return AudioPlayerWidget(player: _audioPlayer!);
    } 
    else {
      return Column(
        children: [
          const Icon(Icons.insert_drive_file, size: 100),
          Text(basename(_filePath)),
          ElevatedButton(
            onPressed: () => OpenFile.open(_filePath).then((result) {
              if (result.type == ResultType.error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('打开文件失败: ${result.message}')),
                );
              }
            }),
            child: const Text('打开文件'),
          ),
        ],
      );
    }
  }
}

// 音频播放器组件
class AudioPlayerWidget extends StatelessWidget {
  final AudioPlayer player;

  const AudioPlayerWidget({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final processing = state?.processingState ?? ProcessingState.idle;
            
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: processing == ProcessingState.ready
                      ? player.play
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.pause),
                  onPressed: player.pause,
                ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: player.stop,
                ),
              ],
            );
          },
        ),
        StreamBuilder<Duration>(
          stream: player.durationStream as Stream<Duration>?,
          builder: (context, snapshot) {
            final duration = snapshot.data ?? Duration.zero;
            return StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                var position = snapshot.data ?? Duration.zero;
                if (position > duration) position = duration;
                return Slider(
                  min: 0,
                  max: duration.inMilliseconds.toDouble(),
                  value: position.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    player.seek(Duration(milliseconds: value.toInt()));
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
class FileViewerPage extends StatefulWidget {
  final String fileUrl;

  const FileViewerPage({super.key, required this.fileUrl});

  @override
  _FileViewerPageState createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  File? _localFile;
  bool _isDownloading = false;

  Future<void> _downloadFile() async {
    setState(() => _isDownloading = true);
    try {
      final file = await FileDownload.downloadFile(widget.fileUrl);
      setState(() => _localFile = File(file));
    } catch (e) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text('下载失败: $e')),
      );
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(basename(widget.fileUrl))),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _localFile == null && !_isDownloading
                  ? ElevatedButton(
                      onPressed: _downloadFile,
                      child: const Text('下载文件'),
                    )
                  : _isDownloading
                      ? const CircularProgressIndicator()
                      : FilePreview(
                          fileUrl: widget.fileUrl,
                          localFile: _localFile,
                        ),
            ),
          ),
          if (_localFile != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () => OpenFile.open(_localFile!.path),
                    child: const Text('打开文件'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => FileViewerPage(
                            fileUrl: widget.fileUrl,
                          ),
                        ),
                      );
                    },
                    child: const Text('分享'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
  void navigateToFileViewer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileViewerPage(
          fileUrl: 'http://192.168.233.1:5000/api/upload/video.mp4',
        ),
      ),
    );
  }