import React, { useState, useEffect } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { 
  Bell, 
  Terminal as TerminalIcon, 
  CheckCircle, 
  XCircle, 
  Settings, 
  AlertTriangle,
  Minimize2,
  Maximize2,
  X
} from 'lucide-react';

import Sidebar from './components/Sidebar';
import OperationsPanel from './components/OperationsPanel';
import NotificationsPanel from './components/NotificationsPanel';
import TerminalPanel from './components/TerminalPanel';
import SettingsPanel from './components/SettingsPanel';

const App = () => {
  const [activePanel, setActivePanel] = useState('operations');
  const [events, setEvents] = useState({
    pending_operations: [],
    notifications: [],
    has_pending: false,
    unread_notifications: 0
  });
  const [isLoading, setIsLoading] = useState(true);

  // Load initial data
  useEffect(() => {
    const loadEvents = async () => {
      try {
        const response = await invoke('get_events');
        setEvents(response);
      } catch (error) {
        console.error('Failed to load events:', error);
      } finally {
        setIsLoading(false);
      }
    };

    loadEvents();
    
    // Refresh events every 5 seconds
    const interval = setInterval(loadEvents, 5000);
    
    return () => clearInterval(interval);
  }, []);

  // Listen for real-time events from Rust backend
  useEffect(() => {
    const unlistenPromises = [
      listen('operation_added', (event) => {
        setEvents(prev => ({
          ...prev,
          pending_operations: [...prev.pending_operations, event.payload],
          has_pending: true
        }));
      }),
      
      listen('operation_updated', (event) => {
        setEvents(prev => ({
          ...prev,
          pending_operations: prev.pending_operations.map(op =>
            op.id === event.payload.id ? event.payload : op
          )
        }));
      }),
      
      listen('notification_added', (event) => {
        setEvents(prev => ({
          ...prev,
          notifications: [...prev.notifications, event.payload],
          unread_notifications: prev.unread_notifications + 1
        }));
      })
    ];

    return () => {
      Promise.all(unlistenPromises).then(unlisteners => {
        unlisteners.forEach(unlisten => unlisten());
      });
    };
  }, []);

  const handleApproveOperation = async (operationId) => {
    try {
      await invoke('approve_operation', { operationId });
      // Refresh events to get updated status
      const response = await invoke('get_events');
      setEvents(response);
    } catch (error) {
      console.error('Failed to approve operation:', error);
    }
  };

  const handleRejectOperation = async (operationId) => {
    try {
      await invoke('reject_operation', { operationId });
      // Refresh events to get updated status
      const response = await invoke('get_events');
      setEvents(response);
    } catch (error) {
      console.error('Failed to reject operation:', error);
    }
  };

  const handleClearNotifications = async () => {
    try {
      await invoke('clear_notifications');
      setEvents(prev => ({
        ...prev,
        notifications: prev.notifications.map(n => ({ ...n, dismissed: true })),
        unread_notifications: 0
      }));
    } catch (error) {
      console.error('Failed to clear notifications:', error);
    }
  };

  const renderPanel = () => {
    switch (activePanel) {
      case 'operations':
        return (
          <OperationsPanel
            operations={events.pending_operations}
            onApprove={handleApproveOperation}
            onReject={handleRejectOperation}
          />
        );
      case 'notifications':
        return (
          <NotificationsPanel
            notifications={events.notifications.filter(n => !n.dismissed)}
            onClear={handleClearNotifications}
          />
        );
      case 'terminal':
        return <TerminalPanel />;
      case 'settings':
        return <SettingsPanel />;
      default:
        return <OperationsPanel operations={[]} onApprove={() => {}} onReject={() => {}} />;
    }
  };

  if (isLoading) {
    return (
      <div className="h-screen bg-dark-950 text-dark-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-accent-500 mx-auto mb-4"></div>
          <p className="text-dark-400">Loading MultiappV1 Sidecar...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="h-screen bg-dark-950 text-dark-100 flex overflow-hidden">
      {/* Sidebar */}
      <Sidebar
        activePanel={activePanel}
        onPanelChange={setActivePanel}
        hasPendingOperations={events.has_pending}
        unreadNotifications={events.unread_notifications}
      />
      
      {/* Main Content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Header */}
        <header className="h-12 bg-dark-900 border-b border-dark-700 flex items-center justify-between px-4">
          <div className="flex items-center space-x-2">
            <div className="w-3 h-3 bg-accent-500 rounded-full"></div>
            <h1 className="text-sm font-semibold text-dark-200">
              MultiappV1 Sidecar
            </h1>
            {events.has_pending && (
              <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200">
                <AlertTriangle className="w-3 h-3 mr-1" />
                Pending Approvals
              </span>
            )}
          </div>
          
          <div className="flex items-center space-x-2">
            {events.unread_notifications > 0 && (
              <div className="relative">
                <Bell className="w-4 h-4 text-dark-400" />
                <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-4 w-4 flex items-center justify-center">
                  {events.unread_notifications}
                </span>
              </div>
            )}
          </div>
        </header>
        
        {/* Panel Content */}
        <main className="flex-1 overflow-hidden">
          {renderPanel()}
        </main>
      </div>
    </div>
  );
};

export default App;
