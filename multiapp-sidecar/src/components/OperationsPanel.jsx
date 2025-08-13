import React from 'react';
import { CheckCircle, XCircle, Clock, FileText, Terminal, Code, AlertTriangle } from 'lucide-react';

const OperationsPanel = ({ operations, onApprove, onReject }) => {
  const getOperationIcon = (type) => {
    switch (type) {
      case 'write_file':
        return FileText;
      case 'run_command':
        return Terminal;
      case 'apply_patch':
        return Code;
      default:
        return AlertTriangle;
    }
  };

  const getOperationColor = (status) => {
    switch (status) {
      case 'pending':
        return 'border-orange-500 bg-orange-50 dark:bg-orange-900/20';
      case 'approved':
        return 'border-blue-500 bg-blue-50 dark:bg-blue-900/20';
      case 'completed':
        return 'border-green-500 bg-green-50 dark:bg-green-900/20';
      case 'failed':
        return 'border-red-500 bg-red-50 dark:bg-red-900/20';
      case 'rejected':
        return 'border-gray-500 bg-gray-50 dark:bg-gray-900/20';
      default:
        return 'border-gray-500 bg-gray-50 dark:bg-gray-900/20';
    }
  };

  const formatTimestamp = (timestamp) => {
    return new Date(timestamp).toLocaleTimeString();
  };

  const getOperationSummary = (operation) => {
    const { operation_type, payload } = operation;
    
    switch (operation_type) {
      case 'write_file':
        return `Write file: ${payload.path || 'unknown'}`;
      case 'run_command':
        return `Execute: ${payload.command?.substring(0, 50) || 'unknown'}${payload.command?.length > 50 ? '...' : ''}`;
      case 'apply_patch':
        return `Apply patch to: ${payload.file || 'unknown'}`;
      default:
        return `${operation_type}: ${JSON.stringify(payload).substring(0, 50)}...`;
    }
  };

  const pendingOperations = operations.filter(op => op.status === 'pending');
  const otherOperations = operations.filter(op => op.status !== 'pending');

  return (
    <div className="h-full bg-dark-950 flex flex-col">
      {/* Header */}
      <div className="p-4 border-b border-dark-700">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold text-dark-100">Operations</h2>
            <p className="text-sm text-dark-400">
              Approve or reject operations from GeanyLua CodingBuddy
            </p>
          </div>
          {pendingOperations.length > 0 && (
            <div className="flex items-center space-x-2 px-3 py-1 bg-orange-900/30 border border-orange-700 rounded-full">
              <Clock className="w-4 h-4 text-orange-400" />
              <span className="text-sm text-orange-200">{pendingOperations.length} pending</span>
            </div>
          )}
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-hidden">
        {operations.length === 0 ? (
          <div className="h-full flex items-center justify-center">
            <div className="text-center">
              <Clock className="w-12 h-12 text-dark-600 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-dark-300 mb-2">No operations</h3>
              <p className="text-dark-500">
                Operations from GeanyLua will appear here for approval
              </p>
            </div>
          </div>
        ) : (
          <div className="h-full overflow-y-auto custom-scrollbar">
            <div className="p-4 space-y-4">
              {/* Pending Operations */}
              {pendingOperations.length > 0 && (
                <div className="space-y-3">
                  <h3 className="text-sm font-semibold text-orange-300 uppercase tracking-wide">
                    Pending Approval ({pendingOperations.length})
                  </h3>
                  
                  {pendingOperations.map((operation) => {
                    const Icon = getOperationIcon(operation.operation_type);
                    
                    return (
                      <div
                        key={operation.id}
                        className={`border rounded-lg p-4 ${getOperationColor(operation.status)}`}
                      >
                        <div className="flex items-start justify-between mb-3">
                          <div className="flex items-center space-x-3">
                            <div className="p-2 bg-dark-800 rounded-lg">
                              <Icon className="w-4 h-4 text-dark-300" />
                            </div>
                            <div>
                              <div className="font-medium text-dark-100">
                                {getOperationSummary(operation)}
                              </div>
                              <div className="text-sm text-dark-400">
                                From {operation.source} • {formatTimestamp(operation.timestamp)}
                              </div>
                            </div>
                          </div>
                        </div>
                        
                        {/* Operation Details */}
                        <div className="mb-4 p-3 bg-dark-900/50 rounded border">
                          <pre className="text-xs text-dark-300 font-mono overflow-x-auto">
                            {JSON.stringify(operation.payload, null, 2)}
                          </pre>
                        </div>
                        
                        {/* Actions */}
                        <div className="flex items-center space-x-3">
                          <button
                            onClick={() => onApprove(operation.id)}
                            className="button-primary flex items-center space-x-2 text-sm"
                          >
                            <CheckCircle className="w-4 h-4" />
                            <span>Approve</span>
                          </button>
                          
                          <button
                            onClick={() => onReject(operation.id)}
                            className="button-danger flex items-center space-x-2 text-sm"
                          >
                            <XCircle className="w-4 h-4" />
                            <span>Reject</span>
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
              
              {/* Other Operations */}
              {otherOperations.length > 0 && (
                <div className="space-y-3">
                  <h3 className="text-sm font-semibold text-dark-400 uppercase tracking-wide">
                    Recent Operations ({otherOperations.length})
                  </h3>
                  
                  {otherOperations.slice(0, 10).map((operation) => {
                    const Icon = getOperationIcon(operation.operation_type);
                    
                    return (
                      <div
                        key={operation.id}
                        className={`border rounded-lg p-3 ${getOperationColor(operation.status)}`}
                      >
                        <div className="flex items-center justify-between">
                          <div className="flex items-center space-x-3">
                            <div className="p-1.5 bg-dark-800 rounded">
                              <Icon className="w-3.5 h-3.5 text-dark-400" />
                            </div>
                            <div>
                              <div className="text-sm font-medium text-dark-200">
                                {getOperationSummary(operation)}
                              </div>
                              <div className="text-xs text-dark-500">
                                {formatTimestamp(operation.timestamp)}
                              </div>
                            </div>
                          </div>
                          
                          <span className={`
                            px-2 py-1 rounded text-xs font-medium capitalize
                            ${operation.status === 'completed' ? 'bg-green-900 text-green-200' :
                              operation.status === 'failed' ? 'bg-red-900 text-red-200' :
                              operation.status === 'rejected' ? 'bg-gray-900 text-gray-200' :
                              'bg-blue-900 text-blue-200'}
                          `}>
                            {operation.status}
                          </span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default OperationsPanel;
