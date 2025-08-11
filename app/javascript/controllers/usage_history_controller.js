import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Usage History controller connected")
    this.createModal()
  }

  createModal() {
    if (document.getElementById('usage-history-modal')) return

    const modal = document.createElement('div')
    modal.id = 'usage-history-modal'
    modal.className = 'fixed inset-0 bg-black bg-opacity-50 hidden z-50 flex items-center justify-center p-4'
    modal.innerHTML = `
      <div class="bg-secondary rounded-lg max-w-4xl w-full max-h-[85vh] overflow-hidden">
        <div class="sticky top-0 bg-secondary border-b border-default px-6 py-4 flex justify-between items-center">
          <h2 class="text-xl font-bold text-white">📈 Usage History</h2>
          <button id="close-usage-history" class="text-gray-400 hover:text-white text-2xl">&times;</button>
        </div>
        
        <div id="usage-history-content" class="p-6 overflow-y-auto max-h-[calc(85vh-80px)]">
          <div class="flex justify-center items-center h-32">
            <div class="text-gray-400">Loading usage history...</div>
          </div>
        </div>
      </div>
    `
    document.body.appendChild(modal)

    document.getElementById('close-usage-history').addEventListener('click', () => {
      this.close()
    })

    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        this.close()
      }
    })
  }

  async open() {
    const modal = document.getElementById('usage-history-modal')
    if (!modal) return

    modal.classList.remove('hidden')
    await this.loadUsageHistory()
  }

  close() {
    const modal = document.getElementById('usage-history-modal')
    if (modal) {
      modal.classList.add('hidden')
    }
  }

  async loadUsageHistory() {
    const contentDiv = document.getElementById('usage-history-content')
    
    try {
      const response = await fetch('/api/usage_history', {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (!response.ok) {
        throw new Error('Failed to load usage history')
      }

      const data = await response.json()
      contentDiv.innerHTML = this.renderUsageHistory(data)
    } catch (error) {
      console.error('Error loading usage history:', error)
      contentDiv.innerHTML = `
        <div class="text-red-400 text-center">
          Failed to load usage history. Please try again.
        </div>
      `
    }
  }

  renderUsageHistory(data) {
    return `
      <!-- Overall Statistics -->
      <div class="mb-8">
        <h3 class="text-lg font-semibold text-white mb-4 flex items-center">
          <span class="text-blue-400 mr-2">⏺</span>
          Database Statistics
        </h3>
        <div class="bg-card rounded-lg p-4 border border-default">
          <div class="flex items-center mb-3">
            <span class="text-2xl mr-3">📊</span>
            <span class="text-gray-300 font-medium">Overall Data Statistics</span>
          </div>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div class="text-center">
              <div class="text-2xl font-bold text-blue-400">${data.statistics.prompts_count}</div>
              <div class="text-sm text-gray-400">Prompts</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-green-400">${data.statistics.executions_count}</div>
              <div class="text-sm text-gray-400">Executions</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-yellow-400">${data.statistics.results_count}</div>
              <div class="text-sm text-gray-400">Results</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-purple-400">${data.statistics.templates_count}</div>
              <div class="text-sm text-gray-400">Templates</div>
            </div>
          </div>
          ${data.statistics.results_count > data.statistics.executions_count ? 
            '<div class="text-xs text-gray-400 mt-3">* Some prompts were executed multiple times</div>' : ''}
        </div>
      </div>

      <!-- Recent Prompts -->
      <div class="mb-8">
        <h3 class="text-lg font-semibold text-white mb-4 flex items-center">
          <span class="text-green-400 mr-2">🎯</span>
          Recent Prompts (Last 5)
        </h3>
        <div class="space-y-3">
          ${data.recent_prompts.map((prompt, index) => `
            <div class="bg-card rounded-lg p-4 border border-default hover:border-gray-600 transition-colors">
              <div class="flex justify-between items-start mb-2">
                <div class="flex items-center">
                  <span class="text-lg font-bold text-gray-400 mr-3">${index + 1}.</span>
                  <span class="text-sm font-medium text-white">ID ${prompt.id}</span>
                  <span class="text-xs text-gray-400 ml-3">${this.formatDate(prompt.created_at)}</span>
                </div>
                <span class="text-xs px-2 py-1 bg-blue-500/20 text-blue-400 rounded">${prompt.model}</span>
              </div>
              <div class="ml-8 space-y-1">
                <div class="text-sm">
                  <span class="text-gray-400">System:</span>
                  <span class="text-gray-300 ml-2">${this.truncateText(prompt.system_prompt, 100)}</span>
                </div>
                <div class="text-sm">
                  <span class="text-gray-400">User:</span>
                  <span class="text-gray-300 ml-2">${this.truncateText(prompt.user_prompt, 100)}</span>
                </div>
              </div>
            </div>
          `).join('')}
        </div>
      </div>

      <!-- Model Usage Statistics -->
      <div>
        <h3 class="text-lg font-semibold text-white mb-4 flex items-center">
          <span class="text-yellow-400 mr-2">🤖</span>
          Model Usage Statistics
        </h3>
        <div class="bg-card rounded-lg p-4 border border-default">
          <div class="text-sm text-gray-400 mb-3">Most frequently used models:</div>
          <div class="space-y-3">
            ${data.model_usage.slice(0, 6).map((model, index) => {
              const percentage = (model.count / data.statistics.prompts_count * 100).toFixed(1)
              return `
                <div class="flex items-center justify-between">
                  <div class="flex items-center flex-1">
                    <span class="text-lg font-bold text-gray-500 w-8">${index + 1}.</span>
                    <span class="text-sm text-white flex-1">${model.model}</span>
                  </div>
                  <div class="flex items-center space-x-3">
                    <div class="w-32 bg-gray-700 rounded-full h-2">
                      <div class="bg-gradient-to-r from-blue-500 to-blue-400 h-2 rounded-full" 
                           style="width: ${percentage}%"></div>
                    </div>
                    <span class="text-sm font-medium text-gray-300 w-16 text-right">${model.count} times</span>
                  </div>
                </div>
              `
            }).join('')}
          </div>
          ${data.model_usage.length > 6 ? 
            `<div class="text-xs text-gray-400 mt-3">+ ${data.model_usage.length - 6} more models</div>` : ''}
        </div>
      </div>
    `
  }

  formatDate(dateString) {
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', { 
      year: 'numeric', 
      month: '2-digit', 
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  truncateText(text, maxLength) {
    if (!text) return '(empty)'
    if (text.length <= maxLength) return text
    return text.substring(0, maxLength) + '...'
  }
}