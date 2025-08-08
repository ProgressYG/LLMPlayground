class PromptChannel < ApplicationCable::Channel
  def subscribed
    execution = Execution.find(params[:execution_id])
    stream_for execution
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
  
  def self.broadcast_update(execution, data)
    broadcast_to(execution, data)
  end
  
  def self.broadcast_chunk(execution, iteration_number, chunk)
    broadcast_to(execution, {
      type: 'chunk',
      iteration: iteration_number,
      content: chunk
    })
  end
  
  def self.broadcast_complete(execution, iteration_number, result)
    broadcast_to(execution, {
      type: 'complete',
      iteration: iteration_number,
      result: result.as_json(except: [:created_at, :updated_at])
    })
  end
  
  def self.broadcast_error(execution, iteration_number, error)
    broadcast_to(execution, {
      type: 'error',
      iteration: iteration_number,
      error: error
    })
  end
end