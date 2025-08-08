import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pythonTab", "javascriptTab", "curlTab", "codeContent", "status"]
  
  connect() {
    // Make showCodeModal available globally
    window.showCodeModal = this.show.bind(this)
    
    // Close modal on ESC key
    document.addEventListener("keydown", this.handleEscape.bind(this))
  }
  
  disconnect() {
    delete window.showCodeModal
    document.removeEventListener("keydown", this.handleEscape.bind(this))
  }
  
  async show(executionId, iterationNumber) {
    // Show the modal
    this.element.classList.remove("hidden")
    
    // Reset to Python tab
    this.currentLanguage = "python"
    this.executionId = executionId
    this.iterationNumber = iterationNumber
    
    // Load the code
    await this.loadCode()
  }
  
  async loadCode() {
    try {
      this.codeContentTarget.textContent = "Loading..."
      this.statusTarget.textContent = ""
      
      const response = await fetch(`/api/prompts/${this.executionId}/code?iteration=${this.iterationNumber}&language=${this.currentLanguage}`, {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.codeContentTarget.textContent = data.code
        this.statusTarget.textContent = `${data.provider} API - ${data.model}`
      } else {
        this.codeContentTarget.textContent = "Failed to load code"
        this.statusTarget.textContent = "Error loading code"
      }
    } catch (error) {
      console.error("Error loading code:", error)
      this.codeContentTarget.textContent = "Error: " + error.message
      this.statusTarget.textContent = "Error occurred"
    }
  }
  
  switchLanguage(event) {
    event.preventDefault()
    
    // Get the language from the button
    const language = event.currentTarget.dataset.language
    this.currentLanguage = language
    
    // Update tab styles
    this.pythonTabTarget.classList.remove("text-primary", "border-b-2", "border-blue-500")
    this.pythonTabTarget.classList.add("text-muted")
    
    this.javascriptTabTarget.classList.remove("text-primary", "border-b-2", "border-blue-500")
    this.javascriptTabTarget.classList.add("text-muted")
    
    this.curlTabTarget.classList.remove("text-primary", "border-b-2", "border-blue-500")
    this.curlTabTarget.classList.add("text-muted")
    
    // Activate selected tab
    event.currentTarget.classList.remove("text-muted")
    event.currentTarget.classList.add("text-primary", "border-b-2", "border-blue-500")
    
    // Load code for the selected language
    this.loadCode()
  }
  
  async copyCode(event) {
    event.preventDefault()
    
    const code = this.codeContentTarget.textContent
    
    try {
      await navigator.clipboard.writeText(code)
      
      // Update button text temporarily
      const button = event.currentTarget
      const originalText = button.textContent
      button.textContent = "Copied!"
      button.classList.add("bg-green-500", "text-white")
      
      setTimeout(() => {
        button.textContent = originalText
        button.classList.remove("bg-green-500", "text-white")
      }, 2000)
    } catch (error) {
      console.error("Failed to copy:", error)
      this.statusTarget.textContent = "Failed to copy to clipboard"
    }
  }
  
  close(event) {
    if (event) event.preventDefault()
    this.element.classList.add("hidden")
  }
  
  handleEscape(event) {
    if (event.key === "Escape" && !this.element.classList.contains("hidden")) {
      this.close()
    }
  }
}