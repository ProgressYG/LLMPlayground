class Api::UsageHistoryController < ApplicationController
  def index
    usage_data = UsageHistoryService.new.generate_report
    render json: usage_data
  end
end