// Event handling for the Tauri frontend
// Manages events from GeanyLua and user interactions

use crate::state::{AppState, PendingOperation, NotificationEvent};
use serde_json::Value;
use std::sync::Arc;
use tauri::State;
use tokio::sync::Mutex;

#[tauri::command]
pub async fn get_events(
    state: State<'_, Arc<Mutex<AppState>>>
) -> Result<EventsResponse, String> {
    let app_state = state.lock().await;
    
    Ok(EventsResponse {
        pending_operations: app_state.pending_operations.clone(),
        notifications: app_state.notifications.iter()
            .filter(|n| !n.dismissed)
            .cloned()
            .collect(),
        has_pending: !app_state.pending_operations.is_empty(),
        unread_notifications: app_state.notifications.iter()
            .filter(|n| !n.dismissed)
            .count(),
    })
}

#[tauri::command]
pub async fn approve_operation(
    operation_id: String,
    state: State<'_, Arc<Mutex<AppState>>>
) -> Result<OperationResponse, String> {
    let mut app_state = state.lock().await;
    
    // Find the operation
    if let Some(operation) = app_state.pending_operations.iter().find(|op| op.id == operation_id) {
        let operation_clone = operation.clone();
        
        // Update status to approved
        app_state.update_operation_status(&operation_id, "approved".to_string())
            .map_err(|e| e.to_string())?;
        
        // In a real implementation, this would also execute the operation
        // For now, we just simulate execution
        let result = simulate_operation_execution(&operation_clone).await;
        
        // Update status based on execution result
        let final_status = if result.success { "completed" } else { "failed" };
        app_state.update_operation_status(&operation_id, final_status.to_string())
            .map_err(|e| e.to_string())?;
        
        app_state.add_notification(
            &format!("Operation {} executed: {}", operation_id, 
                    if result.success { "Success" } else { "Failed" }),
            if result.success { "info" } else { "error" }
        );
        
        Ok(OperationResponse {
            operation_id,
            status: final_status.to_string(),
            result: Some(result.message),
        })
    } else {
        Err("Operation not found".to_string())
    }
}

#[tauri::command]
pub async fn reject_operation(
    operation_id: String,
    state: State<'_, Arc<Mutex<AppState>>>
) -> Result<OperationResponse, String> {
    let mut app_state = state.lock().await;
    
    app_state.update_operation_status(&operation_id, "rejected".to_string())
        .map_err(|e| e.to_string())?;
    
    app_state.add_notification(
        &format!("Operation {} rejected by user", operation_id),
        "warning"
    );
    
    Ok(OperationResponse {
        operation_id,
        status: "rejected".to_string(),
        result: None,
    })
}

#[tauri::command]
pub async fn clear_notifications(
    state: State<'_, Arc<Mutex<AppState>>>
) -> Result<(), String> {
    let mut app_state = state.lock().await;
    
    // Mark all notifications as dismissed instead of deleting them
    for notification in &mut app_state.notifications {
        notification.dismissed = true;
    }
    
    app_state.save_state().map_err(|e| e.to_string())?;
    
    Ok(())
}

#[derive(serde::Serialize)]
pub struct EventsResponse {
    pub pending_operations: Vec<PendingOperation>,
    pub notifications: Vec<NotificationEvent>,
    pub has_pending: bool,
    pub unread_notifications: usize,
}

#[derive(serde::Serialize)]
pub struct OperationResponse {
    pub operation_id: String,
    pub status: String,
    pub result: Option<String>,
}

#[derive(serde::Serialize)]
pub struct ExecutionResult {
    pub success: bool,
    pub message: String,
}

// Simulate operation execution - in a real implementation, this would
// communicate back with GeanyLua to actually perform the operation
async fn simulate_operation_execution(operation: &PendingOperation) -> ExecutionResult {
    // Simulate some processing time
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    
    match operation.operation_type.as_str() {
        "write_file" => {
            if let Some(path) = operation.payload.get("path") {
                ExecutionResult {
                    success: true,
                    message: format!("File written to: {}", path.as_str().unwrap_or("unknown")),
                }
            } else {
                ExecutionResult {
                    success: false,
                    message: "Invalid write_file operation: missing path".to_string(),
                }
            }
        }
        
        "apply_patch" => {
            ExecutionResult {
                success: true,
                message: "Patch applied successfully".to_string(),
            }
        }
        
        "run_command" => {
            if let Some(command) = operation.payload.get("command") {
                // Simulate command validation
                let cmd_str = command.as_str().unwrap_or("");
                if cmd_str.contains("rm -rf") || cmd_str.contains("sudo") {
                    ExecutionResult {
                        success: false,
                        message: "Command blocked for security reasons".to_string(),
                    }
                } else {
                    ExecutionResult {
                        success: true,
                        message: format!("Command executed: {}", cmd_str),
                    }
                }
            } else {
                ExecutionResult {
                    success: false,
                    message: "Invalid run_command operation: missing command".to_string(),
                }
            }
        }
        
        _ => {
            ExecutionResult {
                success: false,
                message: format!("Unknown operation type: {}", operation.operation_type),
            }
        }
    }
}
