class LlmExecutionJob < ApplicationJob
  queue_as :default

  def perform(execution_id, streaming = false)
    execution = Execution.find(execution_id)
    prompt = execution.prompt
    
    # Update status to running
    execution.update!(status: 'running')
    
    # Call Python LLM service for each iteration
    (1..execution.iterations).each do |iteration_num|
      begin
        if streaming
          # Call with streaming support
          stream_llm_response(execution, prompt, iteration_num)
        else
          response = call_llm_service(prompt, iteration_num)
          
          # Save result
          result = execution.results.create!(
            iteration_number: iteration_num,
            response_text: response[:text],
            tokens_used: response[:tokens_used],
            response_time_ms: response[:response_time_ms],
            status: response[:status],
            error_message: response[:error_message]
          )
        end
        
      rescue => e
        Rails.logger.error "LLM Execution Error: #{e.message}"
        execution.results.create!(
          iteration_number: iteration_num,
          status: 'error',
          error_message: e.message
        )
        
        # Broadcast error via ActionCable
        PromptChannel.broadcast_error(execution, iteration_num, e.message)
      end
    end
    
    # Update execution status
    execution.update!(
      status: 'completed',
      completed_at: Time.current
    )
    
    # Final broadcast
    ActionCable.server.broadcast(
      "execution_#{execution_id}",
      { status: 'completed' }
    )
  end
  
  private
  
  def call_llm_service(prompt, iteration_num)
    Rails.logger.info "Calling LLM service for iteration #{iteration_num}"
    
    # Call Python FastAPI service
    response = HTTParty.post(
      'http://localhost:8000/generate',
      body: {
        model_id: prompt.selected_model,
        system_prompt: prompt.system_prompt,
        user_prompt: prompt.user_prompt,
        temperature: prompt.parameters['temperature'],
        max_tokens: prompt.parameters['max_tokens'],
        top_p: prompt.parameters['top_p'],
        stream: false
      }.to_json,
      headers: { 'Content-Type' => 'application/json' },
      timeout: 60
    )
    
    if response.success?
      JSON.parse(response.body).symbolize_keys
    else
      raise "LLM Service Error: #{response.code} - #{response.body}"
    end
  rescue => e
    Rails.logger.error "HTTP Request Error: #{e.message}"
    {
      text: '',
      tokens_used: { input: 0, output: 0, total: 0 },
      response_time_ms: 0,
      status: 'error',
      error_message: e.message
    }
  end
  
  def stream_llm_response(execution, prompt, iteration_num)
    Rails.logger.info "Streaming LLM response for iteration #{iteration_num}"
    
    start_time = Time.current
    accumulated_text = ""
    
    # Use Server-Sent Events for streaming
    uri = URI('http://localhost:8000/generate')
    
    request_body = {
      model_id: prompt.selected_model,
      system_prompt: prompt.system_prompt,
      user_prompt: prompt.user_prompt,
      temperature: prompt.parameters['temperature'],
      max_tokens: prompt.parameters['max_tokens'],
      top_p: prompt.parameters['top_p'],
      stream: true
    }.to_json
    
    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = request_body
      
      http.request(request) do |response|
        response.read_body do |chunk|
          # Parse SSE chunks
          chunk.each_line do |line|
            if line.start_with?("data: ")
              data = line[6..-1].strip
              next if data == "[DONE]"
              
              begin
                json_data = JSON.parse(data)
                
                if json_data['done']
                  # Streaming completed
                  Rails.logger.info "Streaming completed for iteration #{iteration_num}"
                elsif json_data['text']
                  content = json_data['text']
                  accumulated_text += content
                  # Broadcast chunk via ActionCable
                  PromptChannel.broadcast_chunk(execution, iteration_num, content)
                end
              rescue JSON::ParserError => e
                Rails.logger.error "Failed to parse streaming chunk: #{e.message}"
              end
            end
          end
        end
      end
    end
    
    # Calculate response time
    response_time_ms = ((Time.current - start_time) * 1000).round
    
    # Save the complete result
    result = execution.results.create!(
      iteration_number: iteration_num,
      response_text: accumulated_text,
      tokens_used: { input: 0, output: accumulated_text.split.length }, # Approximate
      response_time_ms: response_time_ms,
      status: 'completed'
    )
    
    # Broadcast completion
    PromptChannel.broadcast_complete(execution, iteration_num, result)
  rescue => e
    Rails.logger.error "Streaming Error: #{e.message}"
    raise e
  end
end
