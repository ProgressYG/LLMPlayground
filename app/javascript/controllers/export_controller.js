import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Make export functions available globally
    window.exportResult = this.exportResult.bind(this)
    window.copyToClipboard = this.copyToClipboard.bind(this)
  }
  
  disconnect() {
    delete window.exportResult
    delete window.copyToClipboard
  }
  
  async exportResult(executionId, iterationNumber, format = 'json') {
    try {
      const response = await fetch(`/api/prompts/${executionId}/export?iteration=${iterationNumber}&format=${format}`, {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.downloadFile(data.content, data.filename, format)
        this.showNotification(`Exported as ${format.toUpperCase()}`)
      } else {
        this.showNotification("Export failed", "error")
      }
    } catch (error) {
      console.error("Export error:", error)
      this.showNotification("Export error: " + error.message, "error")
    }
  }
  
  downloadFile(content, filename, format) {
    const blob = new Blob([content], { 
      type: format === 'json' ? 'application/json' : 'text/markdown' 
    })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = filename
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
  }
  
  async copyToClipboard(text, button) {
    try {
      await navigator.clipboard.writeText(text)
      
      if (button) {
        const originalText = button.textContent
        button.textContent = "Copied!"
        button.classList.add("bg-green-500", "text-white")
        
        setTimeout(() => {
          button.textContent = originalText
          button.classList.remove("bg-green-500", "text-white")
        }, 2000)
      }
      
      this.showNotification("Copied to clipboard")
    } catch (error) {
      console.error("Copy failed:", error)
      this.showNotification("Failed to copy", "error")
    }
  }
  
  showNotification(message, type = "success") {
    // Create notification element
    const notification = document.createElement("div")
    notification.className = `fixed bottom-4 right-4 px-4 py-2 rounded-lg text-white z-50 ${
      type === "error" ? "bg-red-500" : "bg-green-500"
    }`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    // Auto-remove after 3 seconds
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
}