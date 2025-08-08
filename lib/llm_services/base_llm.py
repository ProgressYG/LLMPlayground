from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, AsyncIterator
import asyncio
import time
from dataclasses import dataclass
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class LLMResponse:
    """Standard response format for all LLM providers"""
    text: str
    model: str
    tokens_used: Dict[str, int]
    response_time_ms: int
    status: str = "success"
    error_message: Optional[str] = None

class BaseLLM(ABC):
    """Base class for all LLM providers"""
    
    def __init__(self, api_key: str, model_id: str):
        self.api_key = api_key
        self.model_id = model_id
        self.timeout = 30  # seconds
        self.max_retries = 3
        
    @abstractmethod
    async def generate(
        self,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 1.0,
        max_tokens: int = 2048,
        top_p: float = 1.0,
        **kwargs
    ) -> LLMResponse:
        """Generate a response from the LLM"""
        pass
    
    @abstractmethod
    async def stream_generate(
        self,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 1.0,
        max_tokens: int = 2048,
        top_p: float = 1.0,
        **kwargs
    ) -> AsyncIterator[str]:
        """Stream response from the LLM"""
        pass
    
    async def retry_with_exponential_backoff(self, func, *args, **kwargs):
        """Retry function with exponential backoff"""
        for attempt in range(self.max_retries):
            try:
                return await func(*args, **kwargs)
            except Exception as e:
                if attempt == self.max_retries - 1:
                    raise e
                    
                wait_time = (2 ** attempt) + 0.1
                logger.warning(f"Attempt {attempt + 1} failed: {e}. Retrying in {wait_time}s...")
                await asyncio.sleep(wait_time)
                
    def calculate_tokens(self, text: str) -> int:
        """Rough estimation of tokens (can be overridden for specific providers)"""
        # Simple estimation: ~4 characters per token
        return len(text) // 4