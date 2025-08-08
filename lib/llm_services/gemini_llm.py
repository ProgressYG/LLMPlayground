import google.generativeai as genai
from google.generativeai.types import HarmCategory, HarmBlockThreshold
from typing import AsyncIterator
import time
import asyncio
from .base_llm import BaseLLM, LLMResponse
import logging

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
            
            # Generate response (Gemini SDK is synchronous, so we run in executor)
            response = await asyncio.get_event_loop().run_in_executor(
                None,
                lambda: self.model.generate_content(
                    full_prompt,
                    generation_config=generation_config,
                    safety_settings=self.safety_settings
                )
            )
            
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