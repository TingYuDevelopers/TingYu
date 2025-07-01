from app.services.qwen_service import audio_generate,analyse_image,daily_talk,model_comment,voice_generate
from app.services.wave2lip_lipmaker_service import video_generate
from app.utils import file_utils

def generate_video(video_path,audio_path, text_path,out_path):
    """
    1.分析图片生成文本描述
    2.使用文本生成语音音频
    3.使用音频和原视频生成唇语同步视频
    """
    #1.图像分析生成简短句子
    description = analyse_image(image_path=video_path)

    #2.将生成的文本保存为文本文本文件
    with open(text_path, 'w', encoding='utf-8') as f:
        f.write(description)

    #3.根据文本生成语音
    voice_audio_path = voice_generate(video_path=video_path,text_path=text_path,out_path=out_path)

    #4.将语音和视频进行 lip sync
    final_video_path = video_generate(video_path,audio_path)

    return final_video_path 