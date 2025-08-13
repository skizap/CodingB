import React, { useState, useEffect } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { Settings, Moon, Shield, Terminal, Save, RefreshCw } from 'lucide-react';

const SettingsPanel = () => {
  const [config, setConfig] = useState({
    theme: 'dark',
    auto_approve_read_ops: true,
    show_notifications: true,
    terminal_shell: '/bin/bash',
    encryption_enabled: false
  });
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

  // Load current configuration
  useEffect(() => {
    const loadConfig = async () => {
      try {
        const currentConfig = await invoke('get_app_config');
        setConfig(currentConfig);
      } catch (error) {
        console.error('Failed to load config:', error);
      } finally {
        setIsLoading(false);
      }
    };

    loadConfig();
  }, []);

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await invoke('update_app_config', { config });
      // Show success notification (you could add a toast here)
      console.log('Configuration saved successfully');
    } catch (error) {
      console.error('Failed to save config:', error);
    } finally {
      setIsSaving(false);
    }
  };

  const handleReset = () => {
    setConfig({
      theme: 'dark',
      auto_approve_read_ops: true,
      show_notifications: true,
      terminal_shell: '/bin/bash',
      encryption_enabled: false
    });
  };

  if (isLoading) {
    return (
      <div className="h-full bg-dark-950 flex items-center justify-center">
        <div className="text-center">
          <RefreshCw className="w-8 h-8 text-dark-600 mx-auto mb-4 animate-spin" />
          <p className="text-dark-400">Loading settings...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full bg-dark-950 flex flex-col">
      {/* Header */}
      <div className="p-4 border-b border-dark-700">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-dark-800 rounded-lg">
              <Settings className="w-4 h-4 text-dark-300" />
            </div>
            <div>
              <h2 className="text-lg font-semibold text-dark-100">Settings</h2>
              <p className="text-sm text-dark-400">
                Configure MultiappV1 Sidecar preferences
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            <button
              onClick={handleReset}
              className="button-secondary text-sm"
            >
              Reset
            </button>
            
            <button
              onClick={handleSave}
              disabled={isSaving}
              className="button-primary flex items-center space-x-2 text-sm"
            >
              {isSaving ? (
                <RefreshCw className="w-4 h-4 animate-spin" />
              ) : (
                <Save className="w-4 h-4" />
              )}
              <span>{isSaving ? 'Saving...' : 'Save'}</span>
            </button>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto custom-scrollbar">
        <div className="p-6 space-y-8">
          {/* Appearance Section */}
          <section>
            <div className="flex items-center space-x-2 mb-4">
              <Moon className="w-5 h-5 text-dark-400" />
              <h3 className="text-lg font-semibold text-dark-100">Appearance</h3>
            </div>
            
            <div className="space-y-4 ml-7">
              <div>
                <label className="block text-sm font-medium text-dark-300 mb-2">
                  Theme
                </label>
                <select
                  value={config.theme}
                  onChange={(e) => setConfig({ ...config, theme: e.target.value })}
                  className="input-dark w-48"
                >
                  <option value="dark">Dark</option>
                  <option value="light">Light</option>
                  <option value="auto">Auto</option>
                </select>
                <p className="text-xs text-dark-500 mt-1">
                  Default theme for the sidecar interface
                </p>
              </div>
            </div>
          </section>

          {/* Security Section */}
          <section>
            <div className="flex items-center space-x-2 mb-4">
              <Shield className="w-5 h-5 text-dark-400" />
              <h3 className="text-lg font-semibold text-dark-100">Security</h3>
            </div>
            
            <div className="space-y-4 ml-7">
              <div className="flex items-center justify-between">
                <div>
                  <label className="text-sm font-medium text-dark-300">
                    Auto-approve read operations
                  </label>
                  <p className="text-xs text-dark-500 mt-1">
                    Automatically approve safe read-only operations like file reading and directory listing
                  </p>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={config.auto_approve_read_ops}
                    onChange={(e) => setConfig({ ...config, auto_approve_read_ops: e.target.checked })}
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-dark-700 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-accent-800 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-accent-600"></div>
                </label>
              </div>

              <div className="flex items-center justify-between">
                <div>
                  <label className="text-sm font-medium text-dark-300">
                    Encryption enabled
                  </label>
                  <p className="text-xs text-dark-500 mt-1">
                    Encrypt all persistent state data (requires MULTIAPP_PASSPHRASE environment variable)
                  </p>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={config.encryption_enabled}
                    onChange={(e) => setConfig({ ...config, encryption_enabled: e.target.checked })}
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-dark-700 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-accent-800 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-accent-600"></div>
                </label>
              </div>
            </div>
          </section>

          {/* Terminal Section */}
          <section>
            <div className="flex items-center space-x-2 mb-4">
              <Terminal className="w-5 h-5 text-dark-400" />
              <h3 className="text-lg font-semibold text-dark-100">Terminal</h3>
            </div>
            
            <div className="space-y-4 ml-7">
              <div>
                <label className="block text-sm font-medium text-dark-300 mb-2">
                  Default shell
                </label>
                <input
                  type="text"
                  value={config.terminal_shell}
                  onChange={(e) => setConfig({ ...config, terminal_shell: e.target.value })}
                  className="input-dark w-64"
                  placeholder="/bin/bash"
                />
                <p className="text-xs text-dark-500 mt-1">
                  Path to the shell executable for new terminal sessions
                </p>
              </div>
            </div>
          </section>

          {/* Notifications Section */}
          <section>
            <div className="flex items-center space-x-2 mb-4">
              <Settings className="w-5 h-5 text-dark-400" />
              <h3 className="text-lg font-semibold text-dark-100">Notifications</h3>
            </div>
            
            <div className="space-y-4 ml-7">
              <div className="flex items-center justify-between">
                <div>
                  <label className="text-sm font-medium text-dark-300">
                    Show notifications
                  </label>
                  <p className="text-xs text-dark-500 mt-1">
                    Display system notifications for events and status updates
                  </p>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={config.show_notifications}
                    onChange={(e) => setConfig({ ...config, show_notifications: e.target.checked })}
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-dark-700 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-accent-800 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-accent-600"></div>
                </label>
              </div>
            </div>
          </section>

          {/* System Information */}
          <section className="pt-4 border-t border-dark-800">
            <h3 className="text-lg font-semibold text-dark-100 mb-4">System Information</h3>
            <div className="grid grid-cols-2 gap-4 ml-7">
              <div>
                <div className="text-sm font-medium text-dark-400">Version</div>
                <div className="text-sm text-dark-300">MultiappV1 Sidecar v1.0.0</div>
              </div>
              <div>
                <div className="text-sm font-medium text-dark-400">Backend</div>
                <div className="text-sm text-dark-300">Tauri + Rust</div>
              </div>
              <div>
                <div className="text-sm font-medium text-dark-400">Frontend</div>
                <div className="text-sm text-dark-300">React + Vite</div>
              </div>
              <div>
                <div className="text-sm font-medium text-dark-400">Server Port</div>
                <div className="text-sm text-dark-300">8765 (HTTP)</div>
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>
  );
};

export default SettingsPanel;
