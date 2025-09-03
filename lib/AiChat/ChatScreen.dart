import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'ChatService.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    // 在 Widget 初始化后，立即连接
    // listen: false 是因为我们不在 initState 中监听变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatService>().connect();
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  void _sendMessage(ChatService chatService) {
    chatService.sendMessage(_controller.text, imageFile: _selectedImage);
    _controller.clear();
    setState(() {
      _selectedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 使用 Consumer 来监听 ChatService 的变化并重建 UI
    return Consumer<ChatService>(
      builder: (context, chatService, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('ZhuiYu聊天室'),
          ),
          body: Column(
            children: [
              // 聊天消息列表
              Expanded(
                child: ListView.builder(
                  itemCount: chatService.messages.length,
                  itemBuilder: (context, index) {
                    final message = chatService.messages[index];
                    // ... 在这里构建你的聊天气泡 UI ...
                    // (可以复用你之前的 ListTile 逻辑)
                     return ListTile(
                      title: Align(
                        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: message.isUser ? Colors.blue[100] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.imageUrl != null)
                                Image.network(message.imageUrl!, width: 150, height: 150, fit: BoxFit.cover),
                              if (message.text.isNotEmpty)
                                Text(message.text),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 图片预览
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                       Image.network(_selectedImage!.path, height: 100), // kIsWeb
                       IconButton(icon: Icon(Icons.close), onPressed: () => setState(() => _selectedImage = null)),
                    ]
                  ),
                ),

              // 输入区域
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo),
                      onPressed: chatService.isBotReplying ? null : _pickImage,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(hintText: 'Type your message...'),
                        enabled: !chatService.isBotReplying,
                      ),
                    ),
                    IconButton(
                      icon: chatService.isBotReplying 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()) 
                          : const Icon(Icons.send),
                      onPressed: chatService.isBotReplying ? null : () => _sendMessage(chatService),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}