from anthropic import AsyncAnthropic
from typing import AsyncIterator
import time
from .base_llm import BaseLLM, LLMResponse
import logging

logger = logging.getLogger(__name__)

class AnthropicLLM(BaseLLM):
    """Anthropic Claude models implementation"""
    
    def __init__(self, api_key: str, model_id: str):
        super().__init__(api_key, model_id)
        self.client = AsyncAnthropic(api_key=api_key)
        
        # Map our model IDs to Anthropic model names
        self.model_mapping = {
            'claude-3-5-haiku-20241022': 'claude-3-5-haiku-20241022',
            'claude-sonnet-4-20250514': 'claude-sonnet-4-20250514',
            'claude-opus-4-1-20250805': 'claude-opus-4-1-20250805'
        }
        
    async def generate(
        self,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 1.0,
        max_tokens: int = 2048,
        top_p: float = 1.0,
        **kwargs
    ) -> LLMResponse:
        """Generate response from Anthropic Claude"""
        start_time = time.time()
        
        try:
            # Prepare the message
            message_params = {
                "model": self.model_mapping.get(self.model_id, self.model_id),
                "messages": [{"role": "user", "content": user_prompt}],
                "max_tokens": max_tokens,
                "temperature": temperature
            }
            
            # Claude Opus 4.1 doesn't support both temperature and top_p
            if 'opus-4-1' not in self.model_id:
                message_params["top_p"] = top_p
            
            # Add system prompt if provided
            if system_prompt:
                message_params["system"] = system_prompt
            
            response = await self.retry_with_exponential_backoff(
                self.client.messages.create,
                **message_params
            )
            
            response_time = int((time.time() - start_time) * 1000)
            
            # Extract text from response
            text = ""
            if response.content:
                text = response.content[0].text if hasattr(response.content[0], 'text') else str(response.content[0])
            
            return LLMResponse(
                text=text,
                model=self.model_id,
                tokens_used={
                    'input': response.usage.input_tokens,
                    'output': response.usage.output_tokens,
                    'total': response.usage.input_tokens + response.usage.output_tokens
                },
                response_time_ms=response_time,
                status="success"
            )
            
        except Exception as e:
            logger.error(f"Anthropic generation error: {e}")
            response_time = int((time.time() - start_time) * 1000)
            
            return LLMResponse(
                text="",
                model=self.model_id,
                tokens_used={'input': 0, 'output': 0, 'total': 0},
                response_time_ms=response_time,
                status="error",
                error_message=str(e)
            )
    
    async def stream_generate(
        self,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 1.0,
        max_tokens: int = 2048,
        top_p: float = 1.0,
        **kwargs
    ) -> AsyncIterator[str]:
        """Stream response from Anthropic Claude"""
        try:
            message_params = {
                "model": self.model_mapping.get(self.model_id, self.model_id),
                "messages": [{"role": "user", "content": user_prompt}],
                "max_tokens": max_tokens,
                "temperature": temperature,
                "stream": True
            }
            
            # Claude Opus 4.1 doesn't support both temperature and top_p
            if 'opus-4-1' not in self.model_id:
                message_params["top_p"] = top_p
            
            if system_prompt:
                message_params["system"] = system_prompt
            
            async with self.client.messages.stream(**message_params) as stream:
                async for text in stream.text_stream:
                    yield text
                    
        except Exception as e:
            logger.error(f"Anthropic streaming error: {e}")
            yield f"Error: {str(e)}"