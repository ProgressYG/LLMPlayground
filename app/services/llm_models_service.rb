class LlmModelsService
  MODELS = {
    'claude-3-5-haiku-20241022' => {
      provider: 'anthropic',
      display_name: 'Claude 3.5 Haiku',
      icon: '⚡',
      characteristics: 'Fast & Efficient',
      pricing: {
        input: 0.80,
        output: 4.00,
        display: '$0.80/$4.00'
      },
      max_tokens: 4096,
      context_window: 200000,
      supports_streaming: true
    },
    'claude-sonnet-4-20250514' => {
      provider: 'anthropic',
      display_name: 'Claude Sonnet 4',
      icon: '⚖️',
      characteristics: 'Balanced Performance',
      pricing: {
        input: 3.00,
        output: 15.00,
        display: '$3.00/$15.00'
      },
      max_tokens: 4096,
      context_window: 200000,
      supports_streaming: true
    },
    'claude-opus-4-1-20250805' => {
      provider: 'anthropic',
      display_name: 'Claude Opus 4.1',
      icon: '🧠',
      characteristics: 'Advanced Reasoning',
      pricing: {
        input: 15.00,
        output: 75.00,
        display: '$15.00/$75.00'
      },
      max_tokens: 4096,
      context_window: 200000,
      supports_streaming: true
    },
    'gemini-2.5-flash' => {
      provider: 'google',
      display_name: 'Gemini 2.5 Flash',
      icon: '⚡',
      characteristics: 'Ultra Fast',
      pricing: {
        input: 0.10,
        output: 0.40,
        display: '$0.10/$0.40'
      },
      max_tokens: 8192,
      context_window: 1000000,
      supports_streaming: true
    },
    'gemini-2.5-pro' => {
      provider: 'google',
      display_name: 'Gemini 2.5 Pro',
      icon: '💎',
      characteristics: 'Professional Grade',
      pricing: {
        input: 1.25,
        output: 10.00,
        display: '$1.25/$10.00'
      },
      max_tokens: 8192,
      context_window: 1000000,
      supports_streaming: true
    },
    'gpt-4o-mini' => {
      provider: 'openai',
      display_name: 'GPT-4o Mini',
      icon: '🔹',
      characteristics: 'Cost Effective',
      pricing: {
        input: 0.15,
        output: 0.60,
        display: '$0.15/$0.60'
      },
      max_tokens: 16384,
      context_window: 128000,
      supports_streaming: true
    },
    'gpt-4o' => {
      provider: 'openai',
      display_name: 'GPT-4o',
      icon: '🔷',
      characteristics: 'Most Advanced',
      pricing: {
        input: 2.50,
        output: 10.00,
        display: '$2.50/$10.00'
      },
      max_tokens: 16384,
      context_window: 128000,
      supports_streaming: true
    }
  }.freeze

  def self.all_models
    MODELS.map do |id, model|
      model.merge(
        id: id,
        available: ApiKeyManager.key_available?(model[:provider].to_sym)
      )
    end
  end

  def self.available_models
    all_models.select { |model| model[:available] }
  end

  def self.get_model(model_id)
    model = MODELS[model_id]
    return nil unless model
    
    model.merge(
      id: model_id,
      available: ApiKeyManager.key_available?(model[:provider].to_sym)
    )
  end

  def self.models_by_provider(provider)
    MODELS.select { |_, model| model[:provider] == provider.to_s }
  end

  def self.calculate_cost(model_id, input_tokens, output_tokens)
    model = MODELS[model_id]
    return nil unless model
    
    input_cost = (input_tokens / 1_000_000.0) * model[:pricing][:input]
    output_cost = (output_tokens / 1_000_000.0) * model[:pricing][:output]
    
    {
      input_cost: input_cost.round(4),
      output_cost: output_cost.round(4),
      total_cost: (input_cost + output_cost).round(4)
    }
  end
end