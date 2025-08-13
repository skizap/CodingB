import React from 'react';
import { Bell, Info, AlertTriangle, XCircle, Trash2, BellOff } from 'lucide-react';

const NotificationsPanel = ({ notifications, onClear }) => {
  const getNotificationIcon = (level) => {
    switch (level) {
      case 'error':
        return XCircle;
      case 'warning':
        return AlertTriangle;
      case 'info':
      default:
        return Info;
    }
  };

  const getNotificationColor = (level) => {
    switch (level) {
      case 'error':
        return 'border-red-500 bg-red-50 dark:bg-red-900/20 text-red-800 dark:text-red-200';
      case 'warning':
        return 'border-orange-500 bg-orange-50 dark:bg-orange-900/20 text-orange-800 dark:text-orange-200';
      case 'info':
      default:
        return 'border-blue-500 bg-blue-50 dark:bg-blue-900/20 text-blue-800 dark:text-blue-200';
    }
  };

  const formatTimestamp = (timestamp) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diffInMinutes = Math.floor((now - date) / 60000);
    
    if (diffInMinutes < 1) return 'Just now';
    if (diffInMinutes < 60) return `${diffInMinutes}m ago`;
    
    const diffInHours = Math.floor(diffInMinutes / 60);
    if (diffInHours < 24) return `${diffInHours}h ago`;
    
    const diffInDays = Math.floor(diffInHours / 24);
    return `${diffInDays}d ago`;
  };

  return (
    <div className="h-full bg-dark-950 flex flex-col">
      {/* Header */}
      <div className="p-4 border-b border-dark-700">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold text-dark-100">Notifications</h2>
            <p className="text-sm text-dark-400">
              System events and updates from GeanyLua
            </p>
          </div>
          
          {notifications.length > 0 && (
            <button
              onClick={onClear}
              className="button-secondary flex items-center space-x-2 text-sm"
            >
              <Trash2 className="w-4 h-4" />
              <span>Clear All</span>
            </button>
          )}
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-hidden">
        {notifications.length === 0 ? (
          <div className="h-full flex items-center justify-center">
            <div className="text-center">
              <BellOff className="w-12 h-12 text-dark-600 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-dark-300 mb-2">No notifications</h3>
              <p className="text-dark-500">
                System notifications will appear here
              </p>
            </div>
          </div>
        ) : (
          <div className="h-full overflow-y-auto custom-scrollbar">
            <div className="p-4 space-y-3">
              {notifications.map((notification) => {
                const Icon = getNotificationIcon(notification.level);
                
                return (
                  <div
                    key={notification.id}
                    className={`border rounded-lg p-4 ${getNotificationColor(notification.level)}`}
                  >
                    <div className="flex items-start space-x-3">
                      <div className={`p-2 rounded-lg ${
                        notification.level === 'error' ? 'bg-red-100 dark:bg-red-900/50' :
                        notification.level === 'warning' ? 'bg-orange-100 dark:bg-orange-900/50' :
                        'bg-blue-100 dark:bg-blue-900/50'
                      }`}>
                        <Icon className={`w-4 h-4 ${
                          notification.level === 'error' ? 'text-red-600 dark:text-red-400' :
                          notification.level === 'warning' ? 'text-orange-600 dark:text-orange-400' :
                          'text-blue-600 dark:text-blue-400'
                        }`} />
                      </div>
                      
                      <div className="flex-1 min-w-0">
                        <div className="font-medium mb-1">
                          {notification.message}
                        </div>
                        <div className="text-sm opacity-75">
                          {formatTimestamp(notification.timestamp)}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default NotificationsPanel;
