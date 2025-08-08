import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "leftContent", "rightContent", "leftTitle", "rightTitle"]
  
  connect() {
    this.selectedResults = []
    window.toggleResultSelection = this.toggleSelection.bind(this)
    window.compareSelected = this.compareSelected.bind(this)
  }
  
  disconnect() {
    delete window.toggleResultSelection
    delete window.compareSelected
  }
  
  toggleSelection(executionId, iterationNumber, checkbox) {
    const key = `${executionId}-${iterationNumber}`
    const resultData = {
      executionId,
      iterationNumber,
      element: checkbox.closest('.result-card')
    }
    
    if (checkbox.checked) {
      this.selectedResults.push(resultData)
      checkbox.closest('.result-card').classList.add('border-blue-500', 'border-2')
    } else {
      this.selectedResults = this.selectedResults.filter(r => 
        `${r.executionId}-${r.iterationNumber}` !== key
      )
      checkbox.closest('.result-card').classList.remove('border-blue-500', 'border-2')
    }
    
    // Update compare button visibility
    this.updateCompareButton()
  }
  
  updateCompareButton() {
    let compareBtn = document.getElementById('compare-results-btn')
    
    if (!compareBtn) {
      // Create compare button if it doesn't exist
      const container = document.getElementById('result-tabs').parentElement
      compareBtn = document.createElement('button')
      compareBtn.id = 'compare-results-btn'
      compareBtn.className = 'ml-auto px-4 py-1 bg-blue-500 text-white rounded-lg hover:bg-blue-600 hidden'
      compareBtn.textContent = 'Compare Selected'
      compareBtn.onclick = () => this.compareSelected()
      container.appendChild(compareBtn)
    }
    
    if (this.selectedResults.length >= 2) {
      compareBtn.classList.remove('hidden')
      compareBtn.textContent = `Compare ${this.selectedResults.length} Results`
    } else {
      compareBtn.classList.add('hidden')
    }
  }
  
  async compareSelected() {
    if (this.selectedResults.length < 2) {
      alert('Please select at least 2 results to compare')
      return
    }
    
    // Get the first two selected results for comparison
    const [left, right] = this.selectedResults.slice(0, 2)
    
    // Fetch the data for both results
    const [leftData, rightData] = await Promise.all([
      this.fetchResultData(left.executionId, left.iterationNumber),
      this.fetchResultData(right.executionId, right.iterationNumber)
    ])
    
    // Show comparison modal
    this.showComparison(leftData, rightData)
  }
  
  async fetchResultData(executionId, iterationNumber) {
    try {
      const response = await fetch(`/api/prompts/${executionId}/status`)
      const data = await response.json()
      
      const result = data.results.find(r => r.iteration_number === parseInt(iterationNumber))
      return {
        execution: data.execution,
        result: result,
        prompt: data.execution.prompt
      }
    } catch (error) {
      console.error('Error fetching result:', error)
      return null
    }
  }
  
  showComparison(leftData, rightData) {
    const modal = document.getElementById('compare-modal')
    
    if (!modal) {
      // Create modal if it doesn't exist
      this.createComparisonModal()
    }
    
    // Update modal content
    this.updateComparisonContent(leftData, rightData)
    
    // Show modal
    document.getElementById('compare-modal').classList.remove('hidden')
  }
  
  createComparisonModal() {
    const modalHTML = `
      <div id="compare-modal" class="hidden fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-secondary rounded-lg w-[90%] max-w-7xl max-h-[85%] flex flex-col">
          <div class="flex justify-between items-center p-4 border-b border-default">
            <h2 class="text-xl font-semibold text-primary">Compare Results</h2>
            <button onclick="document.getElementById('compare-modal').classList.add('hidden')" 
                    class="text-muted hover:text-primary text-2xl">×</button>
          </div>
          
          <div class="flex-1 grid grid-cols-2 gap-4 p-4 overflow-hidden">
            <!-- Left side -->
            <div class="flex flex-col h-full">
              <div id="compare-left-title" class="text-primary font-semibold mb-2"></div>
              <div id="compare-left-content" class="flex-1 bg-card rounded-lg p-4 overflow-y-auto">
                <pre class="whitespace-pre-wrap text-primary text-sm"></pre>
              </div>
            </div>
            
            <!-- Right side -->
            <div class="flex flex-col h-full">
              <div id="compare-right-title" class="text-primary font-semibold mb-2"></div>
              <div id="compare-right-content" class="flex-1 bg-card rounded-lg p-4 overflow-y-auto">
                <pre class="whitespace-pre-wrap text-primary text-sm"></pre>
              </div>
            </div>
          </div>
          
          <div class="p-4 border-t border-default">
            <div class="flex justify-between items-center">
              <div id="compare-stats" class="text-sm text-muted"></div>
              <button onclick="document.getElementById('compare-modal').classList.add('hidden')"
                      class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600">
                Close
              </button>
            </div>
          </div>
        </div>
      </div>
    `
    
    document.body.insertAdjacentHTML('beforeend', modalHTML)
  }
  
  updateComparisonContent(leftData, rightData) {
    const leftTitle = document.getElementById('compare-left-title')
    const rightTitle = document.getElementById('compare-right-title')
    const leftContent = document.querySelector('#compare-left-content pre')
    const rightContent = document.querySelector('#compare-right-content pre')
    const stats = document.getElementById('compare-stats')
    
    // Update titles
    leftTitle.textContent = `${leftData.prompt.selected_model} - Iteration #${leftData.result.iteration_number}`
    rightTitle.textContent = `${rightData.prompt.selected_model} - Iteration #${rightData.result.iteration_number}`
    
    // Update content with diff highlighting
    const leftText = leftData.result.response_text || leftData.result.error_message || 'No response'
    const rightText = rightData.result.response_text || rightData.result.error_message || 'No response'
    
    // Simple diff highlighting (highlight different lines)
    const leftLines = leftText.split('\n')
    const rightLines = rightText.split('\n')
    
    leftContent.innerHTML = this.highlightDifferences(leftLines, rightLines, 'left')
    rightContent.innerHTML = this.highlightDifferences(rightLines, leftLines, 'right')
    
    // Update stats
    const leftTokens = leftData.result.tokens_used || {}
    const rightTokens = rightData.result.tokens_used || {}
    
    stats.innerHTML = `
      <span>Response Time: ${leftData.result.response_time_ms}ms vs ${rightData.result.response_time_ms}ms</span>
      <span class="ml-4">Tokens: ${leftTokens.output || 0} vs ${rightTokens.output || 0}</span>
    `
  }
  
  highlightDifferences(lines1, lines2, side) {
    return lines1.map((line, index) => {
      const otherLine = lines2[index] || ''
      const isDifferent = line !== otherLine
      
      if (isDifferent) {
        return `<span class="bg-yellow-500 bg-opacity-20">${this.escapeHtml(line)}</span>`
      }
      return this.escapeHtml(line)
    }).join('\n')
  }
  
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}