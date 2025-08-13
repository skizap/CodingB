import React from 'react';
import { Bell, FileCheck, Terminal as TerminalIcon, Settings, Activity } from 'lucide-react';

const Sidebar = ({ activePanel, onPanelChange, hasPendingOperations, unreadNotifications }) => {
  const menuItems = [
    {
      id: 'operations',
      icon: FileCheck,
      label: 'Operations',
      badge: hasPendingOperations ? '!' : null,
      badgeColor: 'bg-orange-500'
    },
    {
      id: 'notifications',
      icon: Bell,
      label: 'Notifications',
      badge: unreadNotifications > 0 ? unreadNotifications : null,
      badgeColor: 'bg-red-500'
    },
    {
      id: 'terminal',
      icon: TerminalIcon,
      label: 'Terminal'
    },
    {
      id: 'settings',
      icon: Settings,
      label: 'Settings'
    }
  ];

  return (
    <div className="w-16 bg-dark-900 border-r border-dark-700 flex flex-col">
      {/* Logo */}
      <div className="h-12 flex items-center justify-center border-b border-dark-700">
        <div className="w-8 h-8 bg-accent-600 rounded-lg flex items-center justify-center">
          <Activity className="w-5 h-5 text-white" />
        </div>
      </div>
      
      {/* Menu Items */}
      <nav className="flex-1 py-4">
        {menuItems.map((item) => {
          const Icon = item.icon;
          const isActive = activePanel === item.id;
          
          return (
            <div
              key={item.id}
              className={`
                relative mx-2 mb-2 rounded-lg cursor-pointer transition-all duration-200
                ${isActive 
                  ? 'bg-accent-600 text-white' 
                  : 'hover:bg-dark-800 text-dark-400 hover:text-dark-200'
                }
              `}
              onClick={() => onPanelChange(item.id)}
              title={item.label}
            >
              <div className="h-12 flex items-center justify-center">
                <Icon className="w-5 h-5" />
                
                {/* Badge */}
                {item.badge && (
                  <span className={`
                    absolute -top-1 -right-1 min-w-[16px] h-4 px-1 
                    ${item.badgeColor} text-white text-xs font-medium
                    rounded-full flex items-center justify-center
                  `}>
                    {item.badge}
                  </span>
                )}
              </div>
            </div>
          );
        })}
      </nav>
      
      {/* Connection Status */}
      <div className="p-3 border-t border-dark-700">
        <div className="flex items-center justify-center">
          <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" title="Connected to GeanyLua"></div>
        </div>
      </div>
    </div>
  );
};

export default Sidebar;
