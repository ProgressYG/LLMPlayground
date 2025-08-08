class PlaygroundController < ApplicationController
  def index
    @models = LlmModelsService.all_models
    @api_status = ApiKeyManager.all_keys_status
    @templates = Template.ordered
  end
end
