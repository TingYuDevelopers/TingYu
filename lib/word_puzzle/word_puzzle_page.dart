import 'package:flutter/material.dart';
import 'word_tile.dart';

import 'dart:convert'; // 导入dart:convert包以使用jsonEncode

// 导入 http 包
import 'package:http/http.dart' as http;

class WordPuzzlePage extends StatefulWidget {
  const WordPuzzlePage({super.key});

  @override
  _WordPuzzlePageState createState() => _WordPuzzlePageState();
}

class _WordPuzzlePageState extends State<WordPuzzlePage> {
  final List<String> allWords = [
    '我', '爱', '学', '习', '天', '向', '上', '好', '孩', '子'
  ];
  
  List<String> availableWords = [];
  List<String> targetWords = [];
  
  // 放置区高亮状态
  bool _isTargetHighlighted = false;
  
  // 用于跟踪在目标区内排序的拖拽状态
  int? _draggingIndexInTarget; // 正在被拖拽的卡片在targetWords中的索引
  int? _hoveringIndexInTarget; // 拖拽时悬停在哪个卡片上

  @override
  void initState() {
    super.initState();
    _resetPuzzle();
  }

  // 提交结果并发送HTTP请求
  Future<void> _submitResult() async {
    // 【重要】: 后端开发人员需要的功能在此！
    // 这行代码会将拼好的词语以列表（数组）的形式打印到调试控制台。
    // 例如: ['我', '爱', '学', '习']
    print('提交给后端的数组: $targetWords');

    // 拼接成字符串
    String sentence = targetWords.join();
    print('拼接成的字符串: $sentence');

    // 发送 HTTP POST 请求
    final url = Uri.parse('http://192.168.233.1:5000/api/upload'); // 替换为你的 Flask API 地址
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sentence': sentence}),
      );

      if (response.statusCode == 200) {
      print('字符串成功发送到服务器');
    } else {
      print('发送失败，状态码: ${response.statusCode}');
    }

    // 下方是在UI上显示给用户看的对话框，不影响上面的数据输出。
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('拼句完成!'),
        content: Text('你拼出的句子是: $sentence'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  void _resetPuzzle() {
    setState(() {
      availableWords = List.from(allWords);
      targetWords = [];
      _isTargetHighlighted = false;
      _draggingIndexInTarget = null;
      _hoveringIndexInTarget = null;
    });
  }

  // 从目标区移除单词（通过点击删除按钮 或 拖拽出去）
  void _removeWordFromTarget(String word) {
    setState(() {
      if (targetWords.contains(word)) {
        targetWords.remove(word);
        if (!availableWords.contains(word)) {
          availableWords.add(word);
        }
      }
    });
  }
  
  // 在目标区内重新排序
  void _reorderWordsInTarget(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    
    setState(() {
      final word = targetWords.removeAt(oldIndex);
      // 处理索引偏移
      if (newIndex > oldIndex) {
        targetWords.insert(newIndex - 1, word);
      } else {
        targetWords.insert(newIndex, word);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('拼句游戏'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _resetPuzzle,
            tooltip: '重置',
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _submitResult,
            tooltip: '提交',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  '将文字拖到框中组成句子',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 5,
                        color: Colors.black,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 目标区域 - 接收从选择区来的新词
              DragTarget<String>(
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isTargetHighlighted 
                        ? Colors.white.withOpacity(0.5)
                        : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _isTargetHighlighted 
                          ? Colors.yellow
                          : Colors.white,
                        width: _isTargetHighlighted ? 3 : 2,
                      ),
                    ),
                    constraints: BoxConstraints(minHeight: 100),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: targetWords.asMap().entries.map((entry) {
                        final index = entry.key;
                        final word = entry.value;
                        
                        final isDraggingInTarget = _draggingIndexInTarget == index;
                        final isHoveringInTarget = _hoveringIndexInTarget == index;
                        
                        return Draggable<int>(
                          data: index,
                          feedback: WordTile(
                            word: word,
                            isDragging: true,
                            isInTarget: true,
                          ),
                          childWhenDragging: Opacity(opacity: 0.5, child: WordTile(word: word, isInTarget: true)),
                          onDraggableCanceled: (_, __) {
                            _removeWordFromTarget(word);
                          },
                          onDragStarted: () {
                            setState(() {
                              _draggingIndexInTarget = index;
                            });
                          },
                          onDragEnd: (details) {
                             setState(() {
                              _draggingIndexInTarget = null;
                              _hoveringIndexInTarget = null;
                            });
                          },
                          child: DragTarget<int>(
                            builder: (context, candidateData, rejectedData) {
                              return Container(
                                decoration: isHoveringInTarget
                                  ? BoxDecoration(
                                      border: Border.all(
                                        color: Colors.yellowAccent,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    )
                                  : null,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    WordTile(
                                      word: word,
                                      isInTarget: true,
                                      isDragging: isDraggingInTarget,
                                    ),
                                    if (!isDraggingInTarget)
                                      Positioned(
                                        top: -8,
                                        right: -8,
                                        child: GestureDetector(
                                          onTap: () => _removeWordFromTarget(word),
                                          child: Container(
                                            padding: EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                            onWillAcceptWithDetails: (data) {
                              if (data != index) {
                                setState(() {
                                  _hoveringIndexInTarget = index;
                                });
                                return true;
                              }
                              return false;
                            },
                            onAcceptWithDetails: (data) {
                              _reorderWordsInTarget(data.data, index);
                              setState(() {
                                _hoveringIndexInTarget = null;
                              });
                            },
                            onLeave: (data) {
                              setState(() {
                                _hoveringIndexInTarget = null;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
                onWillAcceptWithDetails: (data) {
                  return !targetWords.contains(data);
                },
                onAcceptWithDetails: (details) {
                  setState(() {
                    final String data = details.data;
                    targetWords.add(data);
                    availableWords.remove(data);
                    _isTargetHighlighted = false;
                  });
                },
                onMove: (_) {
                  if (!_isTargetHighlighted) {
                    setState(() {
                      _isTargetHighlighted = true;
                    });
                  }
                },
                onLeave: (_) {
                  if (_isTargetHighlighted) {
                    setState(() {
                      _isTargetHighlighted = false;
                    });
                  }
                },
              ),
              
              SizedBox(height: 16),
              
              // 选词区域 - 同时也是接收从目标区拖回词语的删除区
              Expanded(
                child: DragTarget<int>( 
                  builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;
                    return Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isHovering 
                          ? Colors.red.withOpacity(0.4) 
                          : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: isHovering 
                          ? Border.all(color: Colors.red, width: 2)
                          : null,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth = WordTile.fixedWidth + 20;
                          final crossAxisCount = 
                            (constraints.maxWidth / itemWidth).floor().clamp(2, 6);
                          
                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: WordTile.fixedWidth / WordTile.fixedHeight,
                            ),
                            itemCount: availableWords.length,
                            itemBuilder: (context, index) {
                              final word = availableWords[index];
                              return Center(
                                child: Draggable<String>(
                                  data: word,
                                  feedback: WordTile(
                                    word: word,
                                    isBeingDragged: true,
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.5,
                                    child: WordTile(word: word),
                                  ),
                                  child: WordTile(word: word),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                  onAcceptWithDetails: (DragTargetDetails<int> details) {
                    final int fromTargetIndex = details.data;
                    final word = targetWords[fromTargetIndex];
                    _removeWordFromTarget(word);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}