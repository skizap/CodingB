// MultiappV1 Tauri Sidecar - Main Application
// Provides dark-mode UI, approvals, and terminal pane for GeanyLua CodingBuddy

use std::sync::Arc;
use tokio::sync::Mutex;

mod crypto;
mod server;
mod terminal;
mod events;
mod state;

use state::AppState;
use server::SidecarServer;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_http::init())
        .setup(move |app| {
            let app_handle = app.handle().clone();
            
            // Initialize application state with encryption
            let state = AppState::new(&app_handle)?;
            let shared_state = Arc::new(Mutex::new(state));
            
            // Start the sidecar server for GeanyLua communication
            let server_state = shared_state.clone();
            rt.spawn(async move {
                let server = SidecarServer::new(server_state);
                if let Err(e) = server.start().await {
                    eprintln!("Sidecar server error: {}", e);
                }
            });
            
            // Store state in Tauri's managed state
            app.manage(shared_state);
            
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            events::get_events,
            events::approve_operation,
            events::reject_operation,
            events::clear_notifications,
            terminal::create_terminal,
            terminal::write_to_terminal,
            terminal::resize_terminal,
            terminal::kill_terminal,
            state::get_app_config,
            state::update_app_config
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

fn main() {
    run();
}
