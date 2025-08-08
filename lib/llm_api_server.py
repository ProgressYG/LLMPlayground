from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import uvicorn
import asyncio
import json
from llm_services.llm_factory import LLMFactory
from llm_services.base_llm import LLMResponse
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="LLM API Service", version="1.0.0")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class GenerateRequest(BaseModel):
    model_id: str
    system_prompt: Optional[str] = ""
    user_prompt: str
    temperature: float = 1.0
    max_tokens: int = 2048
    top_p: float = 1.0
    stream: bool = False

class GenerateResponse(BaseModel):
    text: str
    model: str
    tokens_used: dict
    response_time_ms: int
    status: str
    error_message: Optional[str] = None

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "llm_api"}

@app.get("/models")
async def get_available_models():
    """Get list of available models"""
    try:
        models = LLMFactory.get_available_models()
        return {"models": models}
    except Exception as e:
        logger.error(f"Error getting models: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/generate")
async def generate(request: GenerateRequest):
    """Generate text from LLM"""
    try:
        # Create LLM instance
        llm = LLMFactory.create_llm(request.model_id)
        
        if request.stream:
            # Return streaming response
            async def stream_generator():
                async for chunk in llm.stream_generate(
                    system_prompt=request.system_prompt,
                    user_prompt=request.user_prompt,
                    temperature=request.temperature,
                    max_tokens=request.max_tokens,
                    top_p=request.top_p
                ):
                    # Send as Server-Sent Events format
                    yield f"data: {json.dumps({'text': chunk})}\n\n"
                yield f"data: {json.dumps({'done': True})}\n\n"
            
            return StreamingResponse(
                stream_generator(),
                media_type="text/event-stream",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                }
            )
        else:
            # Regular generation
            response = await llm.generate(
                system_prompt=request.system_prompt,
                user_prompt=request.user_prompt,
                temperature=request.temperature,
                max_tokens=request.max_tokens,
                top_p=request.top_p
            )
            
            return GenerateResponse(
                text=response.text,
                model=response.model,
                tokens_used=response.tokens_used,
                response_time_ms=response.response_time_ms,
                status=response.status,
                error_message=response.error_message
            )
            
    except ValueError as e:
        logger.error(f"Value error: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Generation error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/batch_generate")
async def batch_generate(request: GenerateRequest):
    """Generate multiple iterations of the same prompt"""
    iterations = request.dict().get('iterations', 1)
    results = []
    
    try:
        llm = LLMFactory.create_llm(request.model_id)
        
        # Run iterations in parallel
        tasks = []
        for i in range(iterations):
            task = llm.generate(
                system_prompt=request.system_prompt,
                user_prompt=request.user_prompt,
                temperature=request.temperature,
                max_tokens=request.max_tokens,
                top_p=request.top_p
            )
            tasks.append(task)
        
        responses = await asyncio.gather(*tasks)
        
        for i, response in enumerate(responses):
            results.append({
                'iteration': i + 1,
                'text': response.text,
                'tokens_used': response.tokens_used,
                'response_time_ms': response.response_time_ms,
                'status': response.status,
                'error_message': response.error_message
            })
        
        return {"results": results, "model": request.model_id}
        
    except Exception as e:
        logger.error(f"Batch generation error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run("llm_api_server:app", host="0.0.0.0", port=8000, reload=True)