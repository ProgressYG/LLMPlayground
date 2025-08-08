class CodeGeneratorService
  def self.generate(prompt, result, language = 'python')
    case language.to_s.downcase
    when 'python'
      generate_python(prompt, result)
    when 'javascript'
      generate_javascript(prompt, result)
    when 'curl'
      generate_curl(prompt, result)
    else
      generate_python(prompt, result)
    end
  end

  private

  def self.generate_python(prompt, result)
    model = prompt.selected_model
    provider = detect_provider(model)
    
    case provider
    when 'openai'
      generate_openai_python(prompt, result)
    when 'anthropic'
      generate_anthropic_python(prompt, result)
    when 'google'
      generate_gemini_python(prompt, result)
    else
      "# Provider not supported"
    end
  end

  def self.generate_openai_python(prompt, result)
    <<~PYTHON
      from openai import OpenAI
      
      client = OpenAI(
          # defaults to os.environ.get("OPENAI_API_KEY")
          api_key="your_api_key_here",
      )
      
      #{prompt.system_prompt.present? ? "system_message = \"#{escape_quotes(prompt.system_prompt)}\"" : "# No system message"}
      
      response = client.chat.completions.create(
          model="#{prompt.selected_model}",
          messages=[
              #{prompt.system_prompt.present? ? "{\"role\": \"system\", \"content\": system_message}," : ""}
              {"role": "user", "content": "#{escape_quotes(prompt.user_prompt)}"}
          ],
          temperature=#{prompt.parameters['temperature'] || 1.0},
          max_tokens=#{prompt.parameters['max_tokens'] || 2048},
          top_p=#{prompt.parameters['top_p'] || 1.0}
      )
      
      print(response.choices[0].message.content)
    PYTHON
  end

  def self.generate_anthropic_python(prompt, result)
    <<~PYTHON
      import anthropic
      
      client = anthropic.Anthropic(
          # defaults to os.environ.get("ANTHROPIC_API_KEY")
          api_key="your_api_key_here",
      )
      
      message = client.messages.create(
          model="#{map_anthropic_model(prompt.selected_model)}",
          max_tokens=#{prompt.parameters['max_tokens'] || 2048},
          temperature=#{prompt.parameters['temperature'] || 1.0},
          #{prompt.system_prompt.present? ? "system=\"#{escape_quotes(prompt.system_prompt)}\"," : "# No system message"}
          messages=[
              {
                  "role": "user",
                  "content": [
                      {
                          "type": "text",
                          "text": "#{escape_quotes(prompt.user_prompt)}"
                      }
                  ]
              }
          ]
      )
      
      print(message.content[0].text)
    PYTHON
  end

  def self.generate_gemini_python(prompt, result)
    <<~PYTHON
      import google.generativeai as genai
      
      genai.configure(api_key="your_api_key_here")
      
      model = genai.GenerativeModel('#{map_gemini_model(prompt.selected_model)}')
      
      #{prompt.system_prompt.present? ? "# System prompt: #{prompt.system_prompt}" : ""}
      #{prompt.system_prompt.present? ? "full_prompt = f\"System: #{escape_quotes(prompt.system_prompt)}\\\\n\\\\nUser: #{escape_quotes(prompt.user_prompt)}\"" : "full_prompt = \"#{escape_quotes(prompt.user_prompt)}\""}
      
      generation_config = genai.GenerationConfig(
          temperature=#{prompt.parameters['temperature'] || 1.0},
          max_output_tokens=#{prompt.parameters['max_tokens'] || 2048},
          top_p=#{prompt.parameters['top_p'] || 1.0}
      )
      
      response = model.generate_content(
          full_prompt,
          generation_config=generation_config
      )
      
      print(response.text)
    PYTHON
  end

  def self.generate_javascript(prompt, result)
    model = prompt.selected_model
    provider = detect_provider(model)
    
    case provider
    when 'openai'
      generate_openai_javascript(prompt, result)
    when 'anthropic'
      generate_anthropic_javascript(prompt, result)
    else
      "// Provider not supported for JavaScript yet"
    end
  end

  def self.generate_openai_javascript(prompt, result)
    <<~JAVASCRIPT
      import OpenAI from 'openai';
      
      const openai = new OpenAI({
        apiKey: process.env.OPENAI_API_KEY || 'your_api_key_here',
      });
      
      async function main() {
        const messages = [
          #{prompt.system_prompt.present? ? "{ role: 'system', content: '#{escape_quotes(prompt.system_prompt)}' }," : ""}
          { role: 'user', content: '#{escape_quotes(prompt.user_prompt)}' }
        ];
        
        const response = await openai.chat.completions.create({
          model: '#{prompt.selected_model}',
          messages: messages,
          temperature: #{prompt.parameters['temperature'] || 1.0},
          max_tokens: #{prompt.parameters['max_tokens'] || 2048},
          top_p: #{prompt.parameters['top_p'] || 1.0},
        });
        
        console.log(response.choices[0].message.content);
      }
      
      main();
    JAVASCRIPT
  end

  def self.generate_anthropic_javascript(prompt, result)
    <<~JAVASCRIPT
      import Anthropic from '@anthropic-ai/sdk';
      
      const anthropic = new Anthropic({
        apiKey: process.env.ANTHROPIC_API_KEY || 'your_api_key_here',
      });
      
      async function main() {
        const message = await anthropic.messages.create({
          model: '#{map_anthropic_model(prompt.selected_model)}',
          max_tokens: #{prompt.parameters['max_tokens'] || 2048},
          temperature: #{prompt.parameters['temperature'] || 1.0},
          #{prompt.system_prompt.present? ? "system: '#{escape_quotes(prompt.system_prompt)}'," : "// No system message"}
          messages: [
            {
              role: 'user',
              content: [
                {
                  type: 'text',
                  text: '#{escape_quotes(prompt.user_prompt)}'
                }
              ]
            }
          ]
        });
        
        console.log(message.content[0].text);
      }
      
      main();
    JAVASCRIPT
  end

  def self.generate_curl(prompt, result)
    model = prompt.selected_model
    provider = detect_provider(model)
    
    case provider
    when 'openai'
      generate_openai_curl(prompt, result)
    when 'anthropic'
      generate_anthropic_curl(prompt, result)
    else
      "# Provider not supported for cURL yet"
    end
  end

  def self.generate_openai_curl(prompt, result)
    messages = []
    messages << "{\\\"role\\\": \\\"system\\\", \\\"content\\\": \\\"#{escape_quotes(prompt.system_prompt)}\\\"}" if prompt.system_prompt.present?
    messages << "{\\\"role\\\": \\\"user\\\", \\\"content\\\": \\\"#{escape_quotes(prompt.user_prompt)}\\\"}"
    
    <<~CURL
      curl https://api.openai.com/v1/chat/completions \\
        -H "Content-Type: application/json" \\
        -H "Authorization: Bearer YOUR_API_KEY" \\
        -d '{
          "model": "#{prompt.selected_model}",
          "messages": [#{messages.join(', ')}],
          "temperature": #{prompt.parameters['temperature'] || 1.0},
          "max_tokens": #{prompt.parameters['max_tokens'] || 2048},
          "top_p": #{prompt.parameters['top_p'] || 1.0}
        }'
    CURL
  end

  def self.generate_anthropic_curl(prompt, result)
    <<~CURL
      curl https://api.anthropic.com/v1/messages \\
        -H "x-api-key: YOUR_API_KEY" \\
        -H "anthropic-version: 2023-06-01" \\
        -H "content-type: application/json" \\
        -d '{
          "model": "#{map_anthropic_model(prompt.selected_model)}",
          "max_tokens": #{prompt.parameters['max_tokens'] || 2048},
          "temperature": #{prompt.parameters['temperature'] || 1.0},
          #{prompt.system_prompt.present? ? "\"system\": \"#{escape_quotes(prompt.system_prompt)}\"," : ""}
          "messages": [
            {
              "role": "user",
              "content": "#{escape_quotes(prompt.user_prompt)}"
            }
          ]
        }'
    CURL
  end

  def self.detect_provider(model)
    case model
    when /^gpt-4o/
      'openai'
    when /^claude/
      'anthropic'
    when /^gemini/
      'google'
    else
      'unknown'
    end
  end

  def self.map_anthropic_model(model)
    # Map our model IDs to Anthropic's API model names
    case model
    when 'claude-3-5-haiku-20241022'
      'claude-3-5-haiku-20241022'
    when 'claude-sonnet-4-20250514'
      'claude-sonnet-4-20250514'
    when 'claude-opus-4-1-20250805'
      'claude-opus-4-1-20250805'
    else
      model
    end
  end

  def self.map_gemini_model(model)
    # Map our model IDs to Gemini's API model names
    case model
    when 'gemini-2.5-flash'
      'gemini-2.5-flash'
    when 'gemini-2.5-pro'
      'gemini-2.5-pro'
    else
      model
    end
  end

  def self.escape_quotes(text)
    return '' unless text
    text.gsub('"', '\\"').gsub("\n", '\\n')
  end
end