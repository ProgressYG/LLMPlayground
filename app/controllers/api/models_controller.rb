class Api::ModelsController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def index
    models = LlmModelsService.all_models
    api_status = ApiKeyManager.all_keys_status
    
    render json: {
      models: models,
      api_status: api_status
    }
  end
  
  def show
    model = LlmModelsService.get_model(params[:id])
    
    if model
      render json: model
    else
      render json: { error: 'Model not found' }, status: :not_found
    end
  end
end
