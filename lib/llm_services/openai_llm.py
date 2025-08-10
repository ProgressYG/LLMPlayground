from openai import AsyncOpenAI
from typing import AsyncIterator
import time
from .base_llm import BaseLLM, LLMResponse
import logging

logger = logging.getLogger(__name__)

class OpenAILLM(BaseLLM):
    """OpenAI GPT models implementation"""
    
    def __init__(self, api_key: str, model_id: str):
        super().__init__(api_key, model_id)
        self.client = AsyncOpenAI(api_key=api_key)
        
        # Map our model IDs to OpenAI model names
        self.model_mapping = {
            'gpt-4o-mini': 'gpt-4o-mini',
            'gpt-4o': 'gpt-4o',
            'gpt-5': 'gpt-5-2025-08-07',
            'gpt-5-mini': 'gpt-5-mini-2025-08-07'
        }
        
        # Models that don't support temperature/top_p
        self.reasoning_models = {'gpt-5', 'gpt-5-mini'}
        
    async def generate(
        self,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 1.0,
        max_tokens: int = 2048,
        top_p: float = 1.0,
        **kwargs
    ) -> LLMResponse:
        """Generate response from OpenAI"""
        start_time = time.time()
        
        try:
            messages = []
            if system_prompt:
                messages.append({"role": "system", "content": system_prompt})
            messages.append({"role": "user", "content": user_prompt})
            
            # Build completion parameters
            completion_params = {
                "model": self.model_mapping.get(self.model_id, self.model_id),
                "messages": messages,
                "stream": False
            }
            
            # GPT-5 models use different parameter names
            if self.model_id in self.reasoning_models:
                # GPT-5 uses max_completion_tokens instead of max_tokens
                completion_params["max_completion_tokens"] = max_tokens
            else:
                # Other models use max_tokens
                completion_params["max_tokens"] = max_tokens
                completion_params["temperature"] = temperature
                completion_params["top_p"] = top_p
            
            response = await self.retry_with_exponential_backoff(
                self.client.chat.completions.create,
                **completion_params
            )
            
            response_time = int((time.time() - start_time) * 1000)
            
            # Extract response text
            response_text = ""
            if response.choices and len(response.choices) > 0:
                choice = response.choices[0]
                if choice.message and choice.message.content:
                    response_text = choice.message.content
                else:
                    logger.warning(f"No content in message for model {self.model_id}")
                    logger.info(f"Choice finish_reason: {choice.finish_reason if hasattr(choice, 'finish_reason') else 'N/A'}")
                    logger.info(f"Full choice: {choice}")
            
            # Log for debugging
            if not response_text:
                logger.warning(f"Empty response from OpenAI for model {self.model_id}")
                logger.info(f"Usage: input={response.usage.prompt_tokens}, output={response.usage.completion_tokens}")
            
            return LLMResponse(
                text=response_text,
                model=self.model_id,
                tokens_used={
                    'input': response.usage.prompt_tokens,
                    'output': response.usage.completion_tokens,
                    'total': response.usage.total_tokens
                },
                response_time_ms=response_time,
                status="success"
            )
            
        except Exception as e:
            logger.error(f"OpenAI generation error: {e}")
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
        """Stream response from OpenAI"""
        try:
            messages = []
            if system_prompt:
                messages.append({"role": "system", "content": system_prompt})
            messages.append({"role": "user", "content": user_prompt})
            
            # Build completion parameters
            completion_params = {
                "model": self.model_mapping.get(self.model_id, self.model_id),
                "messages": messages,
                "stream": True
            }
            
            # GPT-5 models use different parameter names
            if self.model_id in self.reasoning_models:
                # GPT-5 uses max_completion_tokens instead of max_tokens
                completion_params["max_completion_tokens"] = max_tokens
            else:
                # Other models use max_tokens
                completion_params["max_tokens"] = max_tokens
                completion_params["temperature"] = temperature
                completion_params["top_p"] = top_p
            
            stream = await self.client.chat.completions.create(
                **completion_params
            )
            
            async for chunk in stream:
                if chunk.choices[0].delta.content:
                    yield chunk.choices[0].delta.content
                    
        except Exception as e:
            logger.error(f"OpenAI streaming error: {e}")
            yield f"Error: {str(e)}"