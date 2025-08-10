import google.generativeai as genai
from google.generativeai.types import HarmCategory, HarmBlockThreshold
from typing import AsyncIterator
import time
import asyncio
from .base_llm import BaseLLM, LLMResponse
import logging
import random

logger = logging.getLogger(__name__)

class GeminiLLM(BaseLLM):
    """Google Gemini models implementation"""
    
    def __init__(self, api_key: str, model_id: str):
        super().__init__(api_key, model_id)
        genai.configure(api_key=api_key)
        
        # Map our model IDs to Gemini model names
        self.model_mapping = {
            'gemini-2.5-flash': 'gemini-2.5-flash',
            'gemini-2.5-pro': 'gemini-2.5-pro'
        }
        
        model_name = self.model_mapping.get(model_id, model_id)
        
        # Configure with the most permissive safety settings possible
        # Using HarmBlockThreshold enum values directly
        self.safety_settings = [
            {
                "category": "HARM_CATEGORY_HARASSMENT",
                "threshold": "BLOCK_NONE"
            },
            {
                "category": "HARM_CATEGORY_HATE_SPEECH",
                "threshold": "BLOCK_NONE"
            },
            {
                "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                "threshold": "BLOCK_NONE"
            },
            {
                "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                "threshold": "BLOCK_NONE"
            }
        ]
        
        # Create model with safety settings applied
        self.model = genai.GenerativeModel(
            model_name,
            safety_settings=self.safety_settings
        )
        
    async def generate(
        self,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 1.0,
        max_tokens: int = 2048,
        top_p: float = 1.0,
        **kwargs
    ) -> LLMResponse:
        """Generate response from Google Gemini"""
        start_time = time.time()
        
        try:
            # Combine system and user prompts
            full_prompt = ""
            if system_prompt:
                full_prompt = f"System: {system_prompt}\n\nUser: {user_prompt}"
            else:
                full_prompt = user_prompt
            
            # Add a note for Korean language prompts
            # Sometimes Gemini's safety filters are overly sensitive to non-English text
            has_korean = any(ord(char) >= 0xAC00 and ord(char) <= 0xD7A3 for char in full_prompt)
            if has_korean:
                logger.info("Korean text detected in prompt")
                # Add a hint to Gemini to respond appropriately
                full_prompt = f"[Please provide a helpful response in the same language as the user's input]\n\n{full_prompt}"
            
            # Configure generation parameters
            generation_config = genai.GenerationConfig(
                temperature=temperature,
                max_output_tokens=max_tokens,
                top_p=top_p
            )
            
            # Generate response with retry logic for 500 errors
            max_retries = 3
            retry_count = 0
            response = None
            last_error = None
            
            while retry_count < max_retries:
                try:
                    # Generate response (Gemini SDK is synchronous, so we run in executor)
                    response = await asyncio.get_event_loop().run_in_executor(
                        None,
                        lambda: self.model.generate_content(
                            full_prompt,
                            generation_config=generation_config,
                            safety_settings=self.safety_settings
                        )
                    )
                    break  # Success, exit retry loop
                    
                except Exception as e:
                    error_msg = str(e)
                    # Check if it's a 500 Internal Server Error
                    if "500" in error_msg or "internal error" in error_msg.lower():
                        retry_count += 1
                        last_error = e
                        
                        if retry_count < max_retries:
                            # Exponential backoff with jitter
                            wait_time = (2 ** retry_count) + random.uniform(0, 1)
                            logger.warning(f"Gemini API 500 error, retrying in {wait_time:.1f}s (attempt {retry_count}/{max_retries})")
                            await asyncio.sleep(wait_time)
                        else:
                            logger.error(f"Gemini API failed after {max_retries} retries: {error_msg}")
                            raise e
                    else:
                        # Not a 500 error, don't retry
                        raise e
            
            if response is None and last_error:
                raise last_error
            
            response_time = int((time.time() - start_time) * 1000)
            
            # Extract token counts if available
            tokens_used = {'input': 0, 'output': 0, 'total': 0}
            if hasattr(response, 'usage_metadata'):
                tokens_used = {
                    'input': response.usage_metadata.prompt_token_count,
                    'output': response.usage_metadata.candidates_token_count,
                    'total': response.usage_metadata.total_token_count
                }
            
            # Check if response has valid content
            response_text = ""
            if response.candidates:
                candidate = response.candidates[0]
                if candidate.content and candidate.content.parts:
                    response_text = candidate.content.parts[0].text
                elif hasattr(candidate, 'finish_reason') and candidate.finish_reason:
                    # Handle different finish reasons using numeric values
                    # 1 = STOP, 2 = SAFETY, 3 = MAX_TOKENS, 4 = RECITATION, 5 = OTHER
                    finish_reason_map = {
                        1: "STOP: Natural stop point reached",
                        2: "SAFETY: Response filtered due to safety concerns",
                        3: "MAX_TOKENS: Maximum token limit reached",
                        4: "RECITATION: Response filtered due to recitation",
                        5: "OTHER: Response unavailable"
                    }
                    
                    # Get numeric value of finish_reason
                    finish_reason_value = candidate.finish_reason
                    if hasattr(finish_reason_value, 'value'):
                        finish_reason_value = finish_reason_value.value
                    else:
                        finish_reason_value = int(finish_reason_value)
                    
                    finish_reason_name = finish_reason_map.get(finish_reason_value, f"Unknown reason: {finish_reason_value}")
                    logger.warning(f"Gemini response blocked: {finish_reason_name}")
                    
                    # Log safety ratings if available
                    if finish_reason_value == 2 and hasattr(candidate, 'safety_ratings'):
                        logger.warning(f"Safety ratings: {candidate.safety_ratings}")
                    
                    # If blocked by safety, provide a clear error message
                    if finish_reason_value == 2:
                        error_msg = "The Gemini API blocked this request due to safety filters. "
                        error_msg += "This often happens with certain prompts even when they are legitimate. "
                        error_msg += "Please try rephrasing your prompt or using a different model."
                        
                        return LLMResponse(
                            text="",
                            model=self.model_id,
                            tokens_used=tokens_used,
                            response_time_ms=response_time,
                            status="error",
                            error_message=error_msg
                        )
                    
                    return LLMResponse(
                        text="",
                        model=self.model_id,
                        tokens_used=tokens_used,
                        response_time_ms=response_time,
                        status="error",
                        error_message=f"Response blocked: {finish_reason_name}"
                    )
            else:
                # Try to get text directly if available
                try:
                    response_text = response.text
                except:
                    response_text = ""
            
            return LLMResponse(
                text=response_text,
                model=self.model_id,
                tokens_used=tokens_used,
                response_time_ms=response_time,
                status="success"
            )
            
        except Exception as e:
            logger.error(f"Gemini generation error: {e}")
            response_time = int((time.time() - start_time) * 1000)
            
            # Provide more user-friendly error messages
            error_msg = str(e)
            if "500" in error_msg or "internal error" in error_msg.lower():
                error_msg = "Gemini API is experiencing temporary issues. The system attempted multiple retries but the error persists. Please try again in a few moments or use a different model (Gemini 2.5 Flash is recommended as an alternative)."
            elif "403" in error_msg:
                error_msg = "API key authentication failed. Please check your Gemini API key configuration."
            elif "429" in error_msg:
                error_msg = "Rate limit exceeded. Please wait a moment before trying again."
            elif "400" in error_msg:
                error_msg = "Invalid request. Please check your prompt format and parameters."
            
            return LLMResponse(
                text="",
                model=self.model_id,
                tokens_used={'input': 0, 'output': 0, 'total': 0},
                response_time_ms=response_time,
                status="error",
                error_message=error_msg
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
        """Stream response from Google Gemini"""
        try:
            # Combine system and user prompts
            full_prompt = ""
            if system_prompt:
                full_prompt = f"System: {system_prompt}\n\nUser: {user_prompt}"
            else:
                full_prompt = user_prompt
            
            # Add a note for Korean language prompts
            # Sometimes Gemini's safety filters are overly sensitive to non-English text
            has_korean = any(ord(char) >= 0xAC00 and ord(char) <= 0xD7A3 for char in full_prompt)
            if has_korean:
                logger.info("Korean text detected in prompt")
                # Add a hint to Gemini to respond appropriately
                full_prompt = f"[Please provide a helpful response in the same language as the user's input]\n\n{full_prompt}"
            
            generation_config = genai.GenerationConfig(
                temperature=temperature,
                max_output_tokens=max_tokens,
                top_p=top_p
            )
            
            # Generate streaming response
            response = await asyncio.get_event_loop().run_in_executor(
                None,
                lambda: self.model.generate_content(
                    full_prompt,
                    generation_config=generation_config,
                    safety_settings=self.safety_settings,
                    stream=True
                )
            )
            
            for chunk in response:
                if hasattr(chunk, 'text'):
                    try:
                        yield chunk.text
                    except:
                        # Handle case where chunk doesn't have valid text
                        if hasattr(chunk, 'candidates') and chunk.candidates:
                            candidate = chunk.candidates[0]
                            if candidate.content and candidate.content.parts:
                                yield candidate.content.parts[0].text
                            elif hasattr(candidate, 'finish_reason'):
                                # Check if finish_reason is SAFETY (value = 2)
                                finish_reason_value = candidate.finish_reason
                                if hasattr(finish_reason_value, 'value'):
                                    finish_reason_value = finish_reason_value.value
                                else:
                                    finish_reason_value = int(finish_reason_value)
                                
                                if finish_reason_value == 2:
                                    yield "[Content filtered by Gemini safety settings - please try a different prompt or model]"
                                break
                    
        except Exception as e:
            logger.error(f"Gemini streaming error: {e}")
            yield f"Error: {str(e)}"