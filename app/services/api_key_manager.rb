class ApiKeyManager
  PROVIDERS = {
    openai: 'OPENAI_API_KEY',
    anthropic: 'ANTHROPIC_API_KEY',
    google: 'GOOGLE_GEMINI_API_KEY'
  }.freeze

  def self.get_key(provider)
    env_key = PROVIDERS[provider.to_sym]
    return nil unless env_key
    
    ENV[env_key]
  end

  def self.key_available?(provider)
    key = get_key(provider)
    !key.nil? && !key.empty?
  end

  def self.validate_key_format(provider, key)
    return false if key.nil? || key.empty?
    
    case provider.to_sym
    when :openai
      key.start_with?('sk-')
    when :anthropic
      key.start_with?('sk-ant-')
    when :google
      key.start_with?('AIza')
    else
      false
    end
  end

  def self.all_keys_status
    PROVIDERS.transform_values do |env_key|
      key = ENV[env_key]
      {
        available: !key.nil? && !key.empty?,
        env_key: env_key
      }
    end
  end

  def self.configured_providers
    PROVIDERS.select do |provider, _|
      key_available?(provider)
    end.keys
  end
end