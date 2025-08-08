class Template < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  
  scope :ordered, -> { order(:name) }
  
  # Default parameters if not set
  after_initialize :set_default_parameters
  
  private
  
  def set_default_parameters
    self.default_parameters ||= {
      temperature: 1.0,
      max_tokens: 2031,
      top_p: 0.4
    }
  end
end
