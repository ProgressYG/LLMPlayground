class Prompt < ApplicationRecord
  has_many :executions, dependent: :destroy
  
  validates :user_prompt, presence: true
  validates :selected_model, presence: true
  
  # Default parameters
  after_initialize :set_default_parameters
  
  private
  
  def set_default_parameters
    self.parameters ||= {
      temperature: 1.0,
      max_tokens: 2031,
      top_p: 0.4
    }
  end
end
