// Application state management for MultiappV1 Sidecar
// Handles persistent encrypted state and configuration

use crate::crypto::{CryptoManager, EncryptedData, CryptoError};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use tauri::{AppHandle, Manager};
use tokio::fs;
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SidecarConfig {
    pub theme: String,
    pub auto_approve_read_ops: bool,
    pub show_notifications: bool,
    pub terminal_shell: String,
    pub encryption_enabled: bool,
}

impl Default for SidecarConfig {
    fn default() -> Self {
        Self {
            theme: "dark".to_string(),
            auto_approve_read_ops: true,
            show_notifications: true,
            terminal_shell: "/bin/bash".to_string(),
            encryption_enabled: false,
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct PendingOperation {
    pub id: String,
    pub operation_type: String,
    pub payload: serde_json::Value,
    pub status: String,
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub source: String, // "geanylua" or "sidecar"
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct NotificationEvent {
    pub id: String,
    pub message: String,
    pub level: String, // "info", "warning", "error"
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub dismissed: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PersistedState {
    pub config: SidecarConfig,
    pub pending_operations: Vec<PendingOperation>,
    pub notifications: Vec<NotificationEvent>,
    pub terminal_sessions: HashMap<String, serde_json::Value>,
}

impl Default for PersistedState {
    fn default() -> Self {
        Self {
            config: SidecarConfig::default(),
            pending_operations: Vec::new(),
            notifications: Vec::new(),
            terminal_sessions: HashMap::new(),
        }
    }
}

pub struct AppState {
    pub config: SidecarConfig,
    pub pending_operations: Vec<PendingOperation>,
    pub notifications: Vec<NotificationEvent>,
    pub terminal_sessions: HashMap<String, serde_json::Value>,
    crypto: CryptoManager,
    state_file: PathBuf,
    app_handle: AppHandle,
}

impl AppState {
    pub fn new(app_handle: &AppHandle) -> Result<Self, Box<dyn std::error::Error>> {
        let app_dir = app_handle.path().app_data_dir()?;
        
        // Ensure app directory exists
        std::fs::create_dir_all(&app_dir)?;
        
        let state_file = app_dir.join("sidecar_state.json");
        let crypto = CryptoManager::default();
        
        let mut state = Self {
            config: SidecarConfig::default(),
            pending_operations: Vec::new(),
            notifications: Vec::new(),
            terminal_sessions: HashMap::new(),
            crypto,
            state_file,
            app_handle: app_handle.clone(),
        };
        
        // Load persisted state if it exists
        if let Err(e) = state.load_state() {
            eprintln!("Warning: Failed to load persisted state: {}", e);
            // Add notification about state loading failure
            state.add_notification("Failed to load persisted state", "warning");
        }
        
        Ok(state)
    }
    
    /// Load state from encrypted file
    fn load_state(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if !self.state_file.exists() {
            return Ok(()); // No state file yet, use defaults
        }
        
        let file_content = std::fs::read_to_string(&self.state_file)?;
        
        if self.crypto.is_encryption_enabled() {
            // Try to decrypt the state
            let encrypted_data: EncryptedData = serde_json::from_str(&file_content)?;
            let persisted_state: PersistedState = self.crypto.decrypt_json(&encrypted_data)?;
            
            self.config = persisted_state.config;
            self.pending_operations = persisted_state.pending_operations;
            self.notifications = persisted_state.notifications;
            self.terminal_sessions = persisted_state.terminal_sessions;
        } else {
            // Load unencrypted state
            let persisted_state: PersistedState = serde_json::from_str(&file_content)?;
            
            self.config = persisted_state.config;
            self.pending_operations = persisted_state.pending_operations;
            self.notifications = persisted_state.notifications;
            self.terminal_sessions = persisted_state.terminal_sessions;
        }
        
        Ok(())
    }
    
    /// Save state to encrypted file
    pub fn save_state(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let persisted_state = PersistedState {
            config: self.config.clone(),
            pending_operations: self.pending_operations.clone(),
            notifications: self.notifications.clone(),
            terminal_sessions: self.terminal_sessions.clone(),
        };
        
        let file_content = if self.crypto.is_encryption_enabled() {
            let encrypted_data = self.crypto.encrypt_json(&persisted_state)?;
            serde_json::to_string_pretty(&encrypted_data)?
        } else {
            serde_json::to_string_pretty(&persisted_state)?
        };
        
        std::fs::write(&self.state_file, file_content)?;
        Ok(())
    }
    
    /// Add a new pending operation
    pub fn add_operation(&mut self, operation_type: String, payload: serde_json::Value, source: String) -> String {
        let id = Uuid::new_v4().to_string();
        let operation = PendingOperation {
            id: id.clone(),
            operation_type,
            payload,
            status: "pending".to_string(),
            timestamp: chrono::Utc::now(),
            source,
        };
        
        self.pending_operations.push(operation);
        
        // Emit event to frontend
        if let Err(e) = self.app_handle.emit("operation_added", &self.pending_operations.last()) {
            eprintln!("Failed to emit operation_added event: {}", e);
        }
        
        // Auto-save state
        if let Err(e) = self.save_state() {
            eprintln!("Failed to save state after adding operation: {}", e);
        }
        
        id
    }
    
    /// Update operation status
    pub fn update_operation_status(&mut self, id: &str, status: String) -> Result<(), String> {
        if let Some(op) = self.pending_operations.iter_mut().find(|o| o.id == id) {
            op.status = status.clone();
            
            // Emit event to frontend
            if let Err(e) = self.app_handle.emit("operation_updated", &op) {
                eprintln!("Failed to emit operation_updated event: {}", e);
            }
            
            // Auto-save state
            if let Err(e) = self.save_state() {
                eprintln!("Failed to save state after updating operation: {}", e);
            }
            
            Ok(())
        } else {
            Err("Operation not found".to_string())
        }
    }
    
    /// Remove completed operations
    pub fn clean_completed_operations(&mut self) {
        let initial_len = self.pending_operations.len();
        self.pending_operations.retain(|op| op.status == "pending");
        
        if self.pending_operations.len() != initial_len {
            // Auto-save state
            if let Err(e) = self.save_state() {
                eprintln!("Failed to save state after cleaning operations: {}", e);
            }
        }
    }
    
    /// Add notification
    pub fn add_notification(&mut self, message: &str, level: &str) {
        let notification = NotificationEvent {
            id: Uuid::new_v4().to_string(),
            message: message.to_string(),
            level: level.to_string(),
            timestamp: chrono::Utc::now(),
            dismissed: false,
        };
        
        self.notifications.push(notification);
        
        // Emit event to frontend
        if let Err(e) = self.app_handle.emit("notification_added", &self.notifications.last()) {
            eprintln!("Failed to emit notification_added event: {}", e);
        }
        
        // Auto-save state
        if let Err(e) = self.save_state() {
            eprintln!("Failed to save state after adding notification: {}", e);
        }
    }
    
    /// Clear dismissed notifications
    pub fn clear_notifications(&mut self) {
        let initial_len = self.notifications.len();
        self.notifications.retain(|n| !n.dismissed);
        
        if self.notifications.len() != initial_len {
            // Auto-save state
            if let Err(e) = self.save_state() {
                eprintln!("Failed to save state after clearing notifications: {}", e);
            }
        }
    }
}

// Tauri command handlers
#[tauri::command]
pub async fn get_app_config(
    state: tauri::State<'_, std::sync::Arc<tokio::sync::Mutex<AppState>>>
) -> Result<SidecarConfig, String> {
    let state = state.lock().await;
    Ok(state.config.clone())
}

#[tauri::command]
pub async fn update_app_config(
    config: SidecarConfig,
    state: tauri::State<'_, std::sync::Arc<tokio::sync::Mutex<AppState>>>
) -> Result<(), String> {
    let mut state = state.lock().await;
    state.config = config;
    state.save_state().map_err(|e| e.to_string())?;
    Ok(())
}
