import 'package:flutter/material.dart';

class WordTile extends StatelessWidget {
  final String word;
  final bool isDragging; // 在拖拽目标区内排序时，代表拖拽的那个
  final bool isInTarget; // 是否在目标区
  final bool isBeingDragged; // 是否正从选择区被拖拽出来

  // 固定尺寸
  static const double fixedWidth = 70.0;
  static const double fixedHeight = 60.0;

  // 最大缩放尺寸（略大于放置区）
  static const double maxScale = 1.3;

  const WordTile({
    Key? key,
    required this.word,
    this.isDragging = false,
    this.isInTarget = false,
    this.isBeingDragged = false, // 新增参数
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = isInTarget ? Colors.green : Colors.blue;
    // 限制缩放范围：正常状态1.0，拖拽状态1.3
    final scale = (isDragging || isBeingDragged) ? maxScale : 1.0;

    return Transform.scale(
      scale: scale,
      child: Material(
        color: Colors.transparent,
        elevation: (isDragging || isBeingDragged) ? 8 : 2,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: fixedWidth,
          height: fixedHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: isBeingDragged // 根据新参数显示边框
                ? Border.all(color: Colors.yellow, width: 3)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: (isDragging || isBeingDragged) ? 8 : 4,
                offset: Offset(0, (isDragging || isBeingDragged) ? 4 : 2),
              )
            ],
          ),
          child: Text(
            word,
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}