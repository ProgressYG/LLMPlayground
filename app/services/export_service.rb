class ExportService
  def self.to_json(execution, iteration = nil)
    data = build_export_data(execution, iteration)
    JSON.pretty_generate(data)
  end

  def self.to_markdown(execution, iteration = nil)
    data = build_export_data(execution, iteration)
    
    markdown = []
    markdown << "# LLM API Playground Export"
    markdown << ""
    markdown << "**Date:** #{data[:exported_at]}"
    markdown << "**Model:** #{data[:model]}"
    markdown << ""
    
    # Parameters
    markdown << "## Parameters"
    markdown << "- **Temperature:** #{data[:parameters][:temperature]}"
    markdown << "- **Max Tokens:** #{data[:parameters][:max_tokens]}"
    markdown << "- **Top P:** #{data[:parameters][:top_p]}"
    markdown << ""
    
    # Prompts
    markdown << "## Prompts"
    if data[:prompts][:system].present?
      markdown << "### System Prompt"
      markdown << "```"
      markdown << data[:prompts][:system]
      markdown << "```"
      markdown << ""
    end
    
    markdown << "### User Prompt"
    markdown << "```"
    markdown << data[:prompts][:user]
    markdown << "```"
    markdown << ""
    
    # Results
    markdown << "## Results"
    data[:results].each do |result|
      markdown << "### Iteration ##{result[:iteration]}"
      markdown << "- **Response Time:** #{result[:response_time_ms]}ms"
      markdown << "- **Tokens Used:** Input: #{result[:tokens][:input]}, Output: #{result[:tokens][:output]}"
      markdown << ""
      markdown << "#### Response"
      markdown << "```"
      markdown << result[:response]
      markdown << "```"
      markdown << ""
    end
    
    markdown.join("\n")
  end
  
  private
  
  def self.build_export_data(execution, iteration = nil)
    prompt = execution.prompt
    results = if iteration
      execution.results.where(iteration_number: iteration)
    else
      execution.results.order(:iteration_number)
    end
    
    {
      exported_at: Time.current.iso8601,
      model: prompt.selected_model,
      parameters: {
        temperature: prompt.parameters['temperature'],
        max_tokens: prompt.parameters['max_tokens'],
        top_p: prompt.parameters['top_p']
      },
      prompts: {
        system: prompt.system_prompt,
        user: prompt.user_prompt
      },
      results: results.map do |result|
        {
          iteration: result.iteration_number,
          response: result.response_text,
          response_time_ms: result.response_time_ms,
          tokens: {
            input: result.tokens_used&.dig('input') || 0,
            output: result.tokens_used&.dig('output') || 0
          },
          status: result.status,
          error: result.error_message
        }
      end,
      execution: {
        id: execution.id,
        iterations: execution.iterations,
        status: execution.status,
        started_at: execution.started_at&.iso8601,
        completed_at: execution.completed_at&.iso8601
      }
    }
  end
end