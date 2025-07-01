import unittest
from unittest.mock import patch, MagicMock
import os

# Assuming qwen_service is in app.services.qwen_service
from app.services import qwen_service

class TestQwenService(unittest.TestCase):
    """Test cases for qwen_service.py functions"""

    def test_analyse_image_success(self):
        """Test analyse_image with a mock image path and successful response"""
        # Mock image path
        mock_image_path = "test_image.jpg"
        
        # Create a mock response object with proper nested structure
        mock_content = MagicMock()
        mock_content.text = "This is a test description"
        
        mock_message = MagicMock()
        mock_message.content = [mock_content]
        
        mock_choice = MagicMock()
        mock_choice.message = mock_message
        
        mock_output = MagicMock()
        mock_output.choices = [mock_choice]
        
        # Patch the os.path.exists to return True
        with patch('os.path.exists', return_value=True):
            # Patch the MultiModalConversation.call method
            with patch('app.services.qwen_service.MultiModalConversation.call', return_value=mock_output) as mock_call:
                # Call the function
                result = qwen_service.analyse_image(mock_image_path)
                
                # Assert that the result matches the expected output
                self.assertEqual(result, "This is a test description")
                
                # Assert that the MultiModalConversation.call was called once
                mock_call.assert_called_once_with(
                    api_key=qwen_service.qwen_api_key,
                    model="qwen-vl-plus",
                    messages=[
                        {
                            "role": "system",
                            "content": [
                                {"content": qwen_service.prompt_1}
                            ]
                        },
                        {
                            "role": "user",
                            "content": [
                                {"image": mock_image_path},
                                {"text": "请告诉我图中这个是什么东西，并用一个简短的句子描述。"}
                            ]
                        }
                    ],
                    result_format="text", 
                    top_p=0.2,
                )
    
    def test_analyse_image_file_not_found(self):
        """Test analyse_image with a non-existent image path"""
        # Use a non-existent image path
        non_existent_path = "non_existent_image.jpg"
        
        # Assert that the function raises a FileNotFoundError
        with self.assertRaises(FileNotFoundError):
            qwen_service.analyse_image(non_existent_path)

    def test_daily_talk_success(self):
        """Test daily_talk with a successful response"""
        # Create a mock response object with proper nested structure
        mock_content = MagicMock()
        mock_content.text = "This is a test daily talk response"
        
        mock_message = MagicMock()
        mock_message.content = [mock_content]
        
        mock_choice = MagicMock()
        mock_choice.message = mock_message
        
        mock_output = MagicMock()
        mock_output.choices = [mock_choice]
        
        # Patch the MultiModalConversation.call method
        with patch('app.services.qwen_service.MultiModalConversation.call', return_value=mock_output) as mock_call:
            # Call the function
            result = qwen_service.daily_talk()
            
            # Assert that the result matches the expected output
            self.assertEqual(result, "This is a test daily talk response")
            
            # Assert that the MultiModalConversation.call was called once
            mock_call.assert_called_once_with(
                model="qwen-max",
                messages=[
                    {
                        "role": "system",
                        "content": [
                            {"text": qwen_service.prompt_2}
                        ]
                    },
                    {
                        "role": "user",
                        "content": [
                            {"text": "我听不到声音，我想学习说话"}
                        ]
                    }
                ]
            )

    def test_audio_generate_success(self):
        """Test audio_generate with a mock text and output path"""
        # Mock input parameters
        mock_text = "This is a test sentence."
        mock_out_path = "test_output.wav"
        
        # Create a mock SpeechSynthesizer
        mock_speech_synthesizer = MagicMock()
        
        # Patch the SpeechSynthesizer and open
        with patch('app.services.qwen_service.SpeechSynthesizer', return_value=mock_speech_synthesizer) as mock_ss:
            with patch('builtins.open', MagicMock()) as mock_open:
                # Call the function
                result = qwen_service.audio_generate(mock_text, mock_out_path)
                
                # Assert that the SpeechSynthesizer was called with the correct parameters
                mock_ss.assert_called_once_with(model="cosyvoice-v1", voice="longfeifei_v2")
                
                # Assert that the generate_audio method was called once
                mock_speech_synthesizer.generate_audio.assert_called_once_with(mock_text)
                
                # Assert that open was called with the correct parameters
                mock_open.assert_called_once_with(mock_out_path, "wb")

    def test_voice_generate_success(self):
        """Test voice_generate with mock parameters"""
        # Mock input parameters
        mock_video_path = "test_video.mp4"
        mock_text_path = "test_text.txt"
        mock_out_path = "test_output.wav"
        
        # Create a mock audio object
        mock_audio = b"fake_audio_data"
        
        # Create a mock file_utils.generate_unique_filename
        mock_unique_filename = "unique_test_audio.wav"
        
        # Patch audio_generate and video_generate
        with patch('app.services.qwen_service.audio_generate', return_value=mock_audio) as mock_audio_gen:
            with patch('app.utils.file_utils.generate_unique_filename', return_value=mock_unique_filename) as mock_unique_name:
                with patch('app.services.qwen_service.video_generate', return_value="test_output_video.mp4") as mock_video_gen:
                    # Call the function
                    result = qwen_service.voice_generate(mock_video_path, mock_text_path, mock_out_path)
                    
                    # Assert that audio_generate was called with the correct parameters
                    mock_audio_gen.assert_called_once_with(mock_text_path, mock_out_path)
                    
                    # Assert that generate_unique_filename was called with the correct parameter
                    mock_unique_name.assert_called_once_with(mock_audio)
                    
                    # Assert that video_generate was called with the correct parameters
                    mock_video_gen.assert_called_once_with(mock_video_path, mock_unique_filename)
                    
                    # Assert that the result is the expected output path
                    self.assertEqual(result, "test_output_video.mp4")

    def test_model_comment_success(self):
        """Test model_comment with a mock audio path and successful response"""
        # Mock audio path
        mock_audio_path = "test_audio.wav"
        
        # Create a mock response object
        mock_response = MagicMock()
        mock_response.result.message.content.text = "This is a test comment response"
        
        # Patch the MultiModalConversation.call method
        with patch('app.services.qwen_service.MultiModalConversation.call', return_value=mock_response) as mock_call:
            # Call the function
            result = qwen_service.model_comment(mock_audio_path)
            
            # Assert that the result matches the expected output
            self.assertEqual(result, "This is a test comment response")
            
            # Assert that the MultiModalConversation.call was called once
            mock_call.assert_called_once_with(
                model="qwen-audio-turbo",
                api_key=qwen_service.qwen_api_key,
                messages=[
                    {
                        "role": "user",
                        "content":[
                            {"audio": mock_audio_path},
                            {"text": qwen_service.prompt_2}
                        ]
                    }
                ],
                result_format="message"
            )

if __name__ == '__main__':
    unittest.main()