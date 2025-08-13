import React, { useEffect, useRef, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { Terminal as TerminalIcon, Plus, X, Square } from 'lucide-react';
import { Terminal } from 'xterm';
import { FitAddon } from 'xterm-addon-fit';
import { WebLinksAddon } from 'xterm-addon-web-links';
import 'xterm/css/xterm.css';

const TerminalPanel = () => {
  const terminalRef = useRef(null);
  const [terminal, setTerminal] = useState(null);
  const [fitAddon, setFitAddon] = useState(null);
  const [sessionId, setSessionId] = useState(null);
  const [isConnected, setIsConnected] = useState(false);

  // Initialize terminal
  useEffect(() => {
    if (terminalRef.current && !terminal) {
      const term = new Terminal({
        theme: {
          background: '#0f172a',
          foreground: '#e2e8f0',
          cursor: '#3b82f6',
          selection: '#1e40af',
          black: '#0f172a',
          red: '#ef4444',
          green: '#10b981',
          yellow: '#f59e0b',
          blue: '#3b82f6',
          magenta: '#8b5cf6',
          cyan: '#06b6d4',
          white: '#f1f5f9',
          brightBlack: '#475569',
          brightRed: '#f87171',
          brightGreen: '#34d399',
          brightYellow: '#fbbf24',
          brightBlue: '#60a5fa',
          brightMagenta: '#a78bfa',
          brightCyan: '#22d3ee',
          brightWhite: '#ffffff'
        },
        fontFamily: '"JetBrains Mono", "Fira Code", "Consolas", monospace',
        fontSize: 14,
        lineHeight: 1.2,
        cursorBlink: true,
        allowTransparency: true,
        rows: 24,
        cols: 80
      });

      const fit = new FitAddon();
      const webLinks = new WebLinksAddon();

      term.loadAddon(fit);
      term.loadAddon(webLinks);

      term.open(terminalRef.current);
      fit.fit();

      setTerminal(term);
      setFitAddon(fit);

      // Handle user input
      term.onData(data => {
        if (sessionId) {
          invoke('write_to_terminal', {
            sessionId,
            data
          }).catch(console.error);
        }
      });

      return () => {
        term.dispose();
      };
    }
  }, [terminalRef.current]);

  // Listen for terminal output events
  useEffect(() => {
    if (terminal) {
      const unlisten = listen('terminal_output', (event) => {
        if (event.payload.session_id === sessionId) {
          terminal.write(event.payload.data);
        }
      });

      return () => {
        unlisten.then(fn => fn());
      };
    }
  }, [terminal, sessionId]);

  // Handle window resize
  useEffect(() => {
    const handleResize = () => {
      if (fitAddon && terminal) {
        fitAddon.fit();
        if (sessionId) {
          invoke('resize_terminal', {
            sessionId,
            rows: terminal.rows,
            cols: terminal.cols
          }).catch(console.error);
        }
      }
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [fitAddon, terminal, sessionId]);

  const createNewSession = async () => {
    try {
      const response = await invoke('create_terminal', {
        shell: '/bin/bash',
        rows: terminal?.rows || 24,
        cols: terminal?.cols || 80
      });

      setSessionId(response.session_id);
      setIsConnected(true);

      if (terminal) {
        terminal.clear();
        terminal.write(`\r\n\x1b[32mTerminal session started (${response.session_id})\x1b[0m\r\n`);
        terminal.write(`\x1b[90mShell: ${response.shell}\x1b[0m\r\n`);
        terminal.write(`\x1b[90mSize: ${response.cols}x${response.rows}\x1b[0m\r\n\r\n`);
        terminal.write('$ ');
      }
    } catch (error) {
      console.error('Failed to create terminal session:', error);
      if (terminal) {
        terminal.write(`\r\n\x1b[31mFailed to create terminal session: ${error}\x1b[0m\r\n`);
      }
    }
  };

  const killSession = async () => {
    if (sessionId) {
      try {
        await invoke('kill_terminal', { sessionId });
        setSessionId(null);
        setIsConnected(false);
        
        if (terminal) {
          terminal.write('\r\n\x1b[33mTerminal session ended\x1b[0m\r\n');
        }
      } catch (error) {
        console.error('Failed to kill terminal session:', error);
      }
    }
  };

  return (
    <div className="h-full bg-dark-950 flex flex-col">
      {/* Header */}
      <div className="p-4 border-b border-dark-700">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-dark-800 rounded-lg">
              <TerminalIcon className="w-4 h-4 text-dark-300" />
            </div>
            <div>
              <h2 className="text-lg font-semibold text-dark-100">Terminal</h2>
              <p className="text-sm text-dark-400">
                Embedded terminal emulator
                {sessionId && (
                  <span className="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">
                    <div className="w-1.5 h-1.5 bg-green-500 rounded-full mr-1"></div>
                    Connected
                  </span>
                )}
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            {!isConnected ? (
              <button
                onClick={createNewSession}
                className="button-primary flex items-center space-x-2 text-sm"
              >
                <Plus className="w-4 h-4" />
                <span>New Session</span>
              </button>
            ) : (
              <button
                onClick={killSession}
                className="button-danger flex items-center space-x-2 text-sm"
              >
                <Square className="w-4 h-4" />
                <span>Kill Session</span>
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Terminal Content */}
      <div className="flex-1 overflow-hidden">
        {!isConnected ? (
          <div className="h-full flex items-center justify-center">
            <div className="text-center">
              <TerminalIcon className="w-12 h-12 text-dark-600 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-dark-300 mb-2">No terminal session</h3>
              <p className="text-dark-500 mb-6">
                Create a new terminal session to get started
              </p>
              <button
                onClick={createNewSession}
                className="button-primary flex items-center space-x-2 mx-auto"
              >
                <Plus className="w-4 h-4" />
                <span>New Terminal</span>
              </button>
            </div>
          </div>
        ) : (
          <div className="h-full p-4">
            <div className="terminal-container h-full">
              <div
                ref={terminalRef}
                className="h-full w-full"
                style={{ minHeight: '400px' }}
              />
            </div>
          </div>
        )}
      </div>

      {/* Terminal Info */}
      {sessionId && (
        <div className="p-3 border-t border-dark-700 bg-dark-900">
          <div className="flex items-center justify-between text-xs text-dark-500">
            <span>Session ID: {sessionId}</span>
            <span>
              Size: {terminal?.cols || 80}x{terminal?.rows || 24}
            </span>
          </div>
        </div>
      )}
    </div>
  );
};

export default TerminalPanel;
