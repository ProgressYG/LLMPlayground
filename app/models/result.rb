class Result < ApplicationRecord
  belongs_to :execution
  
  validates :iteration_number, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[success error timeout cancelled] }
  
  scope :successful, -> { where(status: 'success') }
  scope :failed, -> { where(status: 'error') }
  
  def successful?
    status == 'success'
  end
  
  def failed?
    status == 'error'
  end
  
  def input_tokens
    tokens_used&.dig('input') || 0
  end
  
  def output_tokens
    tokens_used&.dig('output') || 0
  end
  
  def total_tokens
    input_tokens + output_tokens
  end
end
