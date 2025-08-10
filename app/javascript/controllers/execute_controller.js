import { Controller } from "@hotwired/stimulus"
import { subscribeToExecution, unsubscribeFromExecution } from "../channels/prompt_channel"

export default class extends Controller {
  connect() {
    console.log("Execute controller connected to:", this.element)
    this.streamingResults = {}
  }

  execute(event) {
    if (event) event.preventDefault()
    console.log("Execute action triggered!")
    this.performExecution()
  }
  
  async performExecution() {
    console.log("Starting execution...")
    
    const modelSelect = document.getElementById("model-select")
    const systemPrompt = document.getElementById("system-prompt").value
    const userPrompt = document.getElementById("user-prompt").value
    const temperature = parseFloat(document.getElementById("temperature-slider").value)
    const maxTokens = parseInt(document.getElementById("max-tokens-slider").value)
    const topP = parseFloat(document.getElementById("top-p-slider").value)
    const iterations = parseInt(document.getElementById("iteration-count").value)
    const streamingEnabled = document.getElementById("streaming-toggle")?.checked || false
    
    // Validation
    if (!modelSelect.value) {
      alert("Please select a model")
      return
    }
    
    if (!userPrompt.trim()) {
      alert("Please enter a user prompt")
      return
    }
    
    // GPT-5 and GPT-5-mini validation for min tokens
    if ((modelSelect.value === 'gpt-5' || modelSelect.value === 'gpt-5-mini') && maxTokens < 2000) {
      alert("GPT-5 models require a minimum of 2000 max tokens. Please increase the Max Tokens value.")
      document.getElementById("max-tokens-slider").value = 2000
      document.getElementById("max-tokens-value").textContent = 2000
      return
    }
    
    // Disable button
    this.element.disabled = true
    this.element.textContent = "Executing..."
    
    try {
      console.log("Sending request to /api/prompts/execute with:", {
        model: modelSelect.value,
        systemPrompt,
        userPrompt,
        temperature,
        maxTokens,
        topP,
        iterations,
        streamingEnabled
      })
      
      const response = await fetch("/api/prompts/execute", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({
          prompt: {
            system_prompt: systemPrompt,
            user_prompt: userPrompt,
            selected_model: modelSelect.value,
            parameters: {
              temperature: temperature,
              max_tokens: maxTokens,
              top_p: topP
            }
          },
          iterations: iterations,
          streaming: streamingEnabled
        })
      })
      
      const data = await response.json()
      
      if (response.ok) {
        // Check if streaming is enabled
        const streamingEnabled = document.getElementById("streaming-toggle")?.checked
        
        if (streamingEnabled) {
          // Subscribe to WebSocket for streaming
          this.subscribeToStreaming(data.execution_id, iterations)
        } else {
          // Start polling for results
          this.pollResults(data.execution_id)
        }
      } else {
        alert("Error: " + (data.error || "Failed to execute prompt"))
      }
    } catch (error) {
      console.error("Execution error:", error)
      alert("Failed to execute prompt: " + error.message)
    } finally {
      this.element.disabled = false
      this.element.textContent = "Execute"
    }
  }
  
  async pollResults(executionId) {
    const pollInterval = setInterval(async () => {
      try {
        const response = await fetch(`/api/prompts/${executionId}/status`)
        const data = await response.json()
        
        if (data.completed) {
          clearInterval(pollInterval)
          this.displayResults(data)
        } else {
          // Update progress
          this.updateProgress(data)
        }
      } catch (error) {
        console.error("Polling error:", error)
        clearInterval(pollInterval)
      }
    }, 1000) // Poll every second
  }
  
  displayResults(data) {
    const tabsContainer = document.getElementById("result-tabs")
    const contentContainer = document.getElementById("result-content")
    
    // Clear existing tabs
    tabsContainer.innerHTML = ""
    contentContainer.innerHTML = ""
    
    // Create tabs for each result
    data.results.forEach((result, index) => {
      // Create tab
      const tab = document.createElement("button")
      tab.className = `px-3 py-1 ${index === 0 ? 'bg-card text-primary' : 'text-muted'} hover:text-primary`
      tab.textContent = `#${result.iteration_number}`
      tab.dataset.iteration = result.iteration_number
      tab.addEventListener("click", () => this.switchTab(result.iteration_number))
      tabsContainer.appendChild(tab)
      
      // Create content
      const content = document.createElement("div")
      content.id = `result-${result.iteration_number}`
      content.className = index === 0 ? "block" : "hidden"
      content.innerHTML = `
        <div class="bg-card rounded-lg p-4 result-card">
          <div class="flex justify-between items-start mb-3">
            <div class="flex items-start space-x-3">
              <input type="checkbox" 
                     class="mt-1"
                     onchange="window.toggleResultSelection(${data.execution.id}, ${result.iteration_number}, this)">
              <div>
                <h4 class="font-semibold text-primary">Iteration #${result.iteration_number}</h4>
                <p class="text-sm text-secondary">
                  Model: ${data.execution.prompt.selected_model} | 
                  Time: ${result.response_time_ms}ms | 
                  Tokens: ${result.tokens_used?.input || 0}/${result.tokens_used?.output || 0}
                </p>
              </div>
            </div>
            <div class="flex space-x-2">
              <button class="text-muted hover:text-primary" title="Copy">📋</button>
              <button class="text-muted hover:text-primary" title="Save">💾</button>
            </div>
          </div>
          <div class="prose prose-invert max-w-none">
            <pre class="whitespace-pre-wrap text-primary">${this.escapeHtml(result.response_text || result.error_message || "No response")}</pre>
          </div>
          <div class="flex items-center space-x-4 mt-4 pt-4 border-t border-default">
            <button class="text-muted hover:text-primary">👍</button>
            <button class="text-muted hover:text-primary">👎</button>
            <button class="text-sm text-secondary hover:text-primary"
                    onclick="window.copyToClipboard(\`${this.escapeHtml(result.response_text || '')}\`, this)">
              Copy
            </button>
            <div class="relative inline-block">
              <button class="text-sm text-secondary hover:text-primary"
                      onclick="this.nextElementSibling.classList.toggle('hidden')">
                Export ▼
              </button>
              <div class="hidden absolute left-0 mt-1 bg-card border border-default rounded-lg shadow-lg z-10">
                <button class="block w-full text-left px-3 py-1 text-sm hover:bg-hover"
                        onclick="window.exportResult(${data.execution.id}, ${result.iteration_number}, 'json')">
                  Export as JSON
                </button>
                <button class="block w-full text-left px-3 py-1 text-sm hover:bg-hover"
                        onclick="window.exportResult(${data.execution.id}, ${result.iteration_number}, 'markdown')">
                  Export as Markdown
                </button>
              </div>
            </div>
            <button class="text-sm bg-blue-500 text-white px-3 py-1 rounded hover:bg-blue-600" 
                    onclick="window.showCodeModal(${data.execution.id}, ${result.iteration_number})">
              Get Code
            </button>
          </div>
        </div>
      `
      contentContainer.appendChild(content)
    })
  }
  
  switchTab(iteration) {
    // Update tab styles
    document.querySelectorAll("#result-tabs button").forEach(tab => {
      if (tab.dataset.iteration == iteration) {
        tab.className = "px-3 py-1 bg-card text-primary hover:text-primary"
      } else {
        tab.className = "px-3 py-1 text-muted hover:text-primary"
      }
    })
    
    // Update content visibility
    document.querySelectorAll("#result-content > div").forEach(content => {
      if (content.id === `result-${iteration}`) {
        content.className = "block"
      } else {
        content.className = "hidden"
      }
    })
  }
  
  updateProgress(data) {
    // Could update a progress indicator here
    console.log("Execution progress:", data)
  }
  
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
  
  subscribeToStreaming(executionId, totalIterations) {
    // Initialize streaming UI
    this.initializeStreamingUI(executionId, totalIterations)
    
    subscribeToExecution(executionId, {
      onConnected: () => {
        console.log(`Streaming started for execution ${executionId}`)
      },
      
      onChunk: (iteration, content) => {
        this.appendStreamingContent(executionId, iteration, content)
      },
      
      onComplete: (iteration, result) => {
        this.finalizeStreamingResult(executionId, iteration, result)
      },
      
      onError: (iteration, error) => {
        this.handleStreamingError(executionId, iteration, error)
      },
      
      onDisconnected: () => {
        console.log(`Streaming ended for execution ${executionId}`)
      }
    })
  }
  
  initializeStreamingUI(executionId, totalIterations) {
    const tabsContainer = document.getElementById("result-tabs")
    const contentContainer = document.getElementById("result-content")
    
    // Clear existing content
    tabsContainer.innerHTML = ""
    contentContainer.innerHTML = ""
    
    // Create tabs and content areas for each iteration
    for (let i = 1; i <= totalIterations; i++) {
      // Create tab
      const tab = document.createElement("button")
      tab.className = `px-3 py-1 ${i === 1 ? 'bg-card text-primary' : 'text-muted'} hover:text-primary`
      tab.textContent = `#${i}`
      tab.dataset.iteration = i
      tab.addEventListener("click", () => this.switchTab(i))
      tabsContainer.appendChild(tab)
      
      // Create content area with streaming placeholder
      const content = document.createElement("div")
      content.id = `result-${i}`
      content.className = i === 1 ? "block" : "hidden"
      content.innerHTML = `
        <div class="bg-card rounded-lg p-4">
          <div class="mb-3">
            <h4 class="font-semibold text-primary">Iteration #${i}</h4>
            <p class="text-sm text-secondary">Streaming...</p>
          </div>
          <div class="prose prose-invert max-w-none">
            <pre id="streaming-content-${executionId}-${i}" class="whitespace-pre-wrap text-primary animate-pulse">Waiting for response...</pre>
          </div>
        </div>
      `
      contentContainer.appendChild(content)
      
      // Initialize streaming result storage
      this.streamingResults[`${executionId}-${i}`] = ""
    }
  }
  
  appendStreamingContent(executionId, iteration, content) {
    const element = document.getElementById(`streaming-content-${executionId}-${iteration}`)
    if (element) {
      // Remove animation on first content
      if (element.classList.contains('animate-pulse')) {
        element.classList.remove('animate-pulse')
        element.textContent = ""
      }
      
      // Append new content
      this.streamingResults[`${executionId}-${iteration}`] += content
      element.textContent = this.streamingResults[`${executionId}-${iteration}`]
      
      // Auto-scroll to bottom
      element.scrollTop = element.scrollHeight
    }
  }
  
  finalizeStreamingResult(executionId, iteration, result) {
    const element = document.getElementById(`streaming-content-${executionId}-${iteration}`)
    if (element) {
      element.classList.remove('animate-pulse')
      
      // Update the parent container with final result info
      const container = element.closest('.bg-card')
      const infoElement = container.querySelector('.text-secondary')
      if (infoElement && result) {
        infoElement.textContent = `Time: ${result.response_time_ms}ms | Tokens: ${result.tokens_used?.input || 0}/${result.tokens_used?.output || 0}`
      }
    }
  }
  
  handleStreamingError(executionId, iteration, error) {
    const element = document.getElementById(`streaming-content-${executionId}-${iteration}`)
    if (element) {
      element.classList.remove('animate-pulse')
      element.classList.add('text-red-500')
      element.textContent = `Error: ${error}`
    }
  }
}