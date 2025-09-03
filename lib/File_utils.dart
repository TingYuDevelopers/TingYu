import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

class FileDownload {
  static final Dio dio = Dio();

  //下载文件并返回本地路径
  static Future<String> downloadFile(String url) async {
    if (!await _requestPermission()){
      throw Exception('没有权限');
    }   

    final filename = basename(url);
    final dir = await getApplicationDocumentsDirectory();
    final savePath = join(dir.path, filename);

    try {
      await dio.download(
        url,
        savePath,
        options: Options(
          receiveTimeout: const Duration(milliseconds: 30000),
          sendTimeout: const Duration(milliseconds: 30000),
        ),
      );
      return savePath;
    } catch (e){
      if (e is DioException) {
        throw Exception('网络请求失败: ${e.message}');
      }
      throw Exception('下载失败: ${e.toString()}');
    }
  }

  static Future<bool> _requestPermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }
}

class FileTypeHelper {
  static bool isImage(String path) {
    final ext = extension(path).toLowerCase();
    return ['.bnp','.jpg','jpeg','gif'].contains(ext);
  } 
  static bool isVideo(String path) {
    final ext = extension(path).toLowerCase();
    return ['.mp4','.avi','.mkv'].contains(ext);
  }
  static bool isAudio(String path) {
    final ext =extension(path).toLowerCase();
    return ['.mp3','.wav','.aac'].contains(ext);
  }
}