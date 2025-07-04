import 'package:flutter/material.dart';
import 'ChatService.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService chattalk = ChatService();
  final TextEditingController _controller = TextEditingController();
  List<dynamic> history = [];
  List<String> messages = [];

  @override
  void initState() {
    super.initState();
    chattalk.responses.listen((response) {
      setState(() {
        messages.add("Bot:${response['message']}");
        history = response['history'];
      });
    });
  }

  void _sendMessage(){
    String text = _controller.text;
    if(text.isNotEmpty){
      setState((){
        messages.add("User:$text");
      });
      chattalk.sendMessage(text,history);
      _controller.clear();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Qwen 对话")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(messages[index]));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(icon: Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}