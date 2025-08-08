from typing import Optional
from .base_llm import BaseLLM
from .openai_llm import OpenAILLM
from .anthropic_llm import AnthropicLLM
from .gemini_llm import GeminiLLM
import os
from dotenv import load_dotenv

load_dotenv()

class LLMFactory:
    """Factory class to create appropriate LLM instances"""
    
    @staticmethod
    def create_llm(model_id: str) -> Optional[BaseLLM]:
        """Create an LLM instance based on model ID"""
        
        # Determine provider from model ID
        if model_id.startswith('gpt'):
            api_key = os.getenv('OPENAI_API_KEY')
            if not api_key:
                raise ValueError("OpenAI API key not found in environment")
            return OpenAILLM(api_key, model_id)
            
        elif model_id.startswith('claude'):
            api_key = os.getenv('ANTHROPIC_API_KEY')
            if not api_key:
                raise ValueError("Anthropic API key not found in environment")
            return AnthropicLLM(api_key, model_id)
            
        elif model_id.startswith('gemini'):
            api_key = os.getenv('GOOGLE_GEMINI_API_KEY')
            if not api_key:
                raise ValueError("Google Gemini API key not found in environment")
            return GeminiLLM(api_key, model_id)
            
        else:
            raise ValueError(f"Unknown model ID: {model_id}")
    
    @staticmethod
    def get_available_models():
        """Get list of available models based on configured API keys"""
        available = []
        
        if os.getenv('OPENAI_API_KEY'):
            available.extend(['gpt-4o', 'gpt-4o-mini'])
            
        if os.getenv('ANTHROPIC_API_KEY'):
            available.extend(['claude-3-5-haiku', 'claude-3-5-sonnet', 'claude-3-opus'])
            
        if os.getenv('GOOGLE_GEMINI_API_KEY'):
            available.extend(['gemini-2-flash', 'gemini-2-pro'])
            
        return available