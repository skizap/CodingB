// HTTP Server for GeanyLua communication
// Supports both HTTP localhost and Unix domain sockets

use crate::state::AppState;
use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Method, Request, Response, Server, StatusCode};
use serde_json::{json, Value};
use std::convert::Infallible;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::Mutex;
use tower_http::cors::{CorsLayer, Any};
use anyhow::Result;

const DEFAULT_PORT: u16 = 8765;
const UNIX_SOCKET_PATH: &str = "/tmp/multiapp-sidecar.sock";

pub struct SidecarServer {
    state: Arc<Mutex<AppState>>,
}

impl SidecarServer {
    pub fn new(state: Arc<Mutex<AppState>>) -> Self {
        Self { state }
    }

    pub async fn start(self) -> Result<()> {
        // Start HTTP server
        let http_handle = tokio::spawn(self.start_http_server());
        
        // Start Unix socket server (if supported)
        let unix_handle = tokio::spawn(self.start_unix_server());

        // Wait for either server to complete (or fail)
        tokio::select! {
            result = http_handle => {
                match result {
                    Ok(Ok(())) => println!("HTTP server completed successfully"),
                    Ok(Err(e)) => eprintln!("HTTP server error: {}", e),
                    Err(e) => eprintln!("HTTP server join error: {}", e),
                }
            }
            result = unix_handle => {
                match result {
                    Ok(Ok(())) => println!("Unix server completed successfully"),
                    Ok(Err(e)) => eprintln!("Unix server error: {}", e),
                    Err(e) => eprintln!("Unix server join error: {}", e),
                }
            }
        }

        Ok(())
    }

    async fn start_http_server(self) -> Result<()> {
        let addr = SocketAddr::from(([127, 0, 0, 1], DEFAULT_PORT));
        
        let state = self.state.clone();
        let make_svc = make_service_fn(move |_conn| {
            let state = state.clone();
            async move {
                Ok::<_, Infallible>(service_fn(move |req| {
                    let state = state.clone();
                    handle_request(req, state)
                }))
            }
        });

        println!("Starting HTTP server on http://{}", addr);
        let server = Server::bind(&addr).serve(make_svc);
        
        if let Err(e) = server.await {
            eprintln!("HTTP server error: {}", e);
        }

        Ok(())
    }

    async fn start_unix_server(self) -> Result<()> {
        // For now, just a placeholder - Unix sockets require additional setup
        println!("Unix socket server would start at: {}", UNIX_SOCKET_PATH);
        
        // Keep this running but not actually doing anything
        loop {
            tokio::time::sleep(tokio::time::Duration::from_secs(60)).await;
        }
    }
}

async fn handle_request(
    req: Request<Body>,
    state: Arc<Mutex<AppState>>
) -> Result<Response<Body>, Infallible> {
    let response = match (req.method(), req.uri().path()) {
        (&Method::GET, "/health") => {
            Response::builder()
                .status(StatusCode::OK)
                .header("content-type", "application/json")
                .body(Body::from(json!({"status": "ok", "service": "multiapp-sidecar"}).to_string()))
                .unwrap()
        }

        (&Method::POST, "/events") => {
            handle_events_endpoint(req, state).await
        }

        (&Method::GET, "/operations") => {
            handle_get_operations(state).await
        }

        (&Method::POST, "/operations/approve") => {
            handle_approve_operation(req, state).await
        }

        (&Method::POST, "/operations/reject") => {
            handle_reject_operation(req, state).await
        }

        (&Method::GET, "/notifications") => {
            handle_get_notifications(state).await
        }

        (&Method::POST, "/notifications/clear") => {
            handle_clear_notifications(state).await
        }

        _ => {
            Response::builder()
                .status(StatusCode::NOT_FOUND)
                .body(Body::from("Not Found"))
                .unwrap()
        }
    };

    Ok(response)
}

async fn handle_events_endpoint(
    req: Request<Body>,
    state: Arc<Mutex<AppState>>
) -> Response<Body> {
    let body_bytes = match hyper::body::to_bytes(req.into_body()).await {
        Ok(bytes) => bytes,
        Err(e) => {
            return Response::builder()
                .status(StatusCode::BAD_REQUEST)
                .body(Body::from(format!("Failed to read body: {}", e)))
                .unwrap();
        }
    };

    let event_data: Value = match serde_json::from_slice(&body_bytes) {
        Ok(data) => data,
        Err(e) => {
            return Response::builder()
                .status(StatusCode::BAD_REQUEST)
                .body(Body::from(format!("Invalid JSON: {}", e)))
                .unwrap();
        }
    };

    // Process the event from GeanyLua
    let mut app_state = state.lock().await;
    
    let event_type = event_data["type"].as_str().unwrap_or("unknown");
    
    match event_type {
        "operation_request" => {
            let operation_type = event_data["operation"].as_str().unwrap_or("unknown").to_string();
            let payload = event_data["payload"].clone();
            
            let operation_id = app_state.add_operation(
                operation_type.clone(),
                payload,
                "geanylua".to_string()
            );
            
            app_state.add_notification(
                &format!("New {} operation pending approval", operation_type),
                "info"
            );
            
            Response::builder()
                .status(StatusCode::OK)
                .header("content-type", "application/json")
                .body(Body::from(json!({
                    "status": "queued",
                    "operation_id": operation_id
                }).to_string()))
                .unwrap()
        }
        
        "chat_message" => {
            let message = event_data["message"].as_str().unwrap_or("");
            app_state.add_notification(
                &format!("Chat: {}", message),
                "info"
            );
            
            Response::builder()
                .status(StatusCode::OK)
                .header("content-type", "application/json")
                .body(Body::from(json!({"status": "received"}).to_string()))
                .unwrap()
        }
        
        _ => {
            Response::builder()
                .status(StatusCode::BAD_REQUEST)
                .body(Body::from("Unknown event type"))
                .unwrap()
        }
    }
}

async fn handle_get_operations(state: Arc<Mutex<AppState>>) -> Response<Body> {
    let app_state = state.lock().await;
    
    Response::builder()
        .status(StatusCode::OK)
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_string(&app_state.pending_operations).unwrap()))
        .unwrap()
}

async fn handle_approve_operation(
    req: Request<Body>,
    state: Arc<Mutex<AppState>>
) -> Response<Body> {
    let body_bytes = match hyper::body::to_bytes(req.into_body()).await {
        Ok(bytes) => bytes,
        Err(e) => {
            return Response::builder()
                .status(StatusCode::BAD_REQUEST)
                .body(Body::from(format!("Failed to read body: {}", e)))
                .unwrap();
        }
    };

    let request_data: Value = match serde_json::from_slice(&body_bytes) {
        Ok(data) => data,
        Err(e) => {
            return Response::builder()
                .status(StatusCode::BAD_REQUEST)
                .body(Body::from(format!("Invalid JSON: {}", e)))
                .unwrap();
        }
    };

    let operation_id = request_data["operation_id"].as_str().unwrap_or("");
    
    let mut app_state = state.lock().await;
    
    match app_state.update_operation_status(operation_id, "approved".to_string()) {
        Ok(()) => {
            app_state.add_notification(
                &format!("Operation {} approved", operation_id),
                "info"
            );
            
            Response::builder()
                .status(StatusCode::OK)
                .header("content-type", "application/json")
                .body(Body::from(json!({"status": "approved"}).to_string()))
                .unwrap()
        }
        Err(e) => {
            Response::builder()
                .status(StatusCode::NOT_FOUND)
                .body(Body::from(e))
                .unwrap()
        }
    }
}

async fn handle_reject_operation(
    req: Request<Body>,
    state: Arc<Mutex<AppState>>
) -> Response<Body> {
    let body_bytes = match hyper::body::to_bytes(req.into_body()).await {
        Ok(bytes) => bytes,
        Err(e) => {
            return Response::builder()
                .status(StatusCode::BAD_REQUEST)
                .body(Body::from(format!("Failed to read body: {}", e)))
                .unwrap();
        }
    };

    let request_data: Value = match serde_json::from_slice(&body_bytes) {
        Ok(data) => data,
        Err(e) => {
            return Response::builder()
                .status(StatusCode::BAD_REQUEST)
                .body(Body::from(format!("Invalid JSON: {}", e)))
                .unwrap();
        }
    };

    let operation_id = request_data["operation_id"].as_str().unwrap_or("");
    
    let mut app_state = state.lock().await;
    
    match app_state.update_operation_status(operation_id, "rejected".to_string()) {
        Ok(()) => {
            app_state.add_notification(
                &format!("Operation {} rejected", operation_id),
                "warning"
            );
            
            Response::builder()
                .status(StatusCode::OK)
                .header("content-type", "application/json")
                .body(Body::from(json!({"status": "rejected"}).to_string()))
                .unwrap()
        }
        Err(e) => {
            Response::builder()
                .status(StatusCode::NOT_FOUND)
                .body(Body::from(e))
                .unwrap()
        }
    }
}

async fn handle_get_notifications(state: Arc<Mutex<AppState>>) -> Response<Body> {
    let app_state = state.lock().await;
    
    Response::builder()
        .status(StatusCode::OK)
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_string(&app_state.notifications).unwrap()))
        .unwrap()
}

async fn handle_clear_notifications(state: Arc<Mutex<AppState>>) -> Response<Body> {
    let mut app_state = state.lock().await;
    app_state.clear_notifications();
    
    Response::builder()
        .status(StatusCode::OK)
        .header("content-type", "application/json")
        .body(Body::from(json!({"status": "cleared"}).to_string()))
        .unwrap()
}
