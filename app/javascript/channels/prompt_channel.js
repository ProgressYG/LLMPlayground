import consumer from "./consumer"

let subscriptions = {}

export function subscribeToExecution(executionId, handlers) {
  // Unsubscribe from existing subscription if any
  if (subscriptions[executionId]) {
    subscriptions[executionId].unsubscribe()
  }
  
  subscriptions[executionId] = consumer.subscriptions.create(
    { 
      channel: "PromptChannel",
      execution_id: executionId 
    },
    {
      connected() {
        console.log(`Connected to prompt channel for execution ${executionId}`)
        if (handlers.onConnected) handlers.onConnected()
      },

      disconnected() {
        console.log(`Disconnected from prompt channel for execution ${executionId}`)
        if (handlers.onDisconnected) handlers.onDisconnected()
      },

      received(data) {
        console.log("Received data:", data)
        
        switch(data.type) {
          case 'chunk':
            if (handlers.onChunk) {
              handlers.onChunk(data.iteration, data.content)
            }
            break
            
          case 'complete':
            if (handlers.onComplete) {
              handlers.onComplete(data.iteration, data.result)
            }
            break
            
          case 'error':
            if (handlers.onError) {
              handlers.onError(data.iteration, data.error)
            }
            break
            
          default:
            console.log("Unknown message type:", data.type)
        }
      }
    }
  )
  
  return subscriptions[executionId]
}

export function unsubscribeFromExecution(executionId) {
  if (subscriptions[executionId]) {
    subscriptions[executionId].unsubscribe()
    delete subscriptions[executionId]
  }
}