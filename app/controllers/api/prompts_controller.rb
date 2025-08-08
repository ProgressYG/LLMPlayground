class Api::PromptsController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def execute
    # Save prompt to database
    prompt = Prompt.create!(prompt_params)
    
    # Create execution record
    execution = prompt.executions.create!(
      iterations: params[:iterations] || 1,
      status: 'pending',
      started_at: Time.current
    )
    
    # Call Python LLM service (streaming disabled)
    LlmExecutionJob.perform_later(execution.id, false)
    
    render json: {
      execution_id: execution.id,
      status: 'started'
    }
  end
  
  def status
    execution = Execution.find(params[:id])
    results = execution.results.order(:iteration_number)
    
    render json: {
      execution: execution.as_json(
        except: [:created_at, :updated_at],
        include: { prompt: { except: [:created_at, :updated_at] } }
      ),
      results: results.as_json(except: [:created_at, :updated_at]),
      completed: execution.completed?
    }
  end
  
  def code
    execution = Execution.find(params[:id])
    iteration = params[:iteration] || 1
    language = params[:language] || 'python'
    
    result = execution.results.find_by(iteration_number: iteration)
    
    if result
      code = CodeGeneratorService.generate(execution.prompt, result, language)
      
      render json: {
        code: code,
        language: language,
        model: execution.prompt.selected_model,
        provider: detect_provider(execution.prompt.selected_model)
      }
    else
      render json: { error: 'Result not found' }, status: :not_found
    end
  end
  
  def export
    execution = Execution.find(params[:id])
    iteration = params[:iteration]
    format = params[:format] || 'json'
    
    content = if format == 'markdown'
      ExportService.to_markdown(execution, iteration)
    else
      ExportService.to_json(execution, iteration)
    end
    
    filename_base = "llm_export_#{execution.id}"
    filename_base += "_iteration_#{iteration}" if iteration
    
    render json: {
      content: content,
      filename: "#{filename_base}.#{format == 'markdown' ? 'md' : 'json'}",
      format: format
    }
  end
  
  private
  
  def detect_provider(model)
    case model
    when /^gpt/
      'OpenAI'
    when /^claude/
      'Anthropic'
    when /^gemini/
      'Google'
    else
      'Unknown'
    end
  end
  
  def prompt_params
    params.require(:prompt).permit(
      :system_prompt,
      :user_prompt,
      :selected_model,
      parameters: [:temperature, :max_tokens, :top_p]
    )
  end
end
