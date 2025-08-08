class Execution < ApplicationRecord
  belongs_to :prompt
  has_many :results, dependent: :destroy
  
  validates :iterations, presence: true, numericality: { in: 1..10 }
  validates :status, inclusion: { in: %w[pending running completed failed cancelled] }
  
  scope :recent, -> { order(created_at: :desc) }
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def running?
    status == 'running'
  end
end
