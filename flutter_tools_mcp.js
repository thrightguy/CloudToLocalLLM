const { MCPServer } = require('mcp-framework');

const server = new MCPServer({
  name: 'flutter-tools',
  version: '1.0.0',
  tools: [
    {
      name: 'get_diagnostics',
      description: 'Get diagnostics for a Dart/Flutter file',
      input_schema: {
        type: 'object',
        properties: {
          file_path: {
            type: 'string',
            description: 'Path to the Dart/Flutter file'
          }
        },
        required: ['file_path']
      }
    },
    {
      name: 'apply_fixes',
      description: 'Apply suggested fixes to a Dart/Flutter file',
      input_schema: {
        type: 'object',
        properties: {
          file_path: {
            type: 'string',
            description: 'Path to the Dart/Flutter file'
          },
          fixes: {
            type: 'array',
            description: 'List of fixes to apply',
            items: {
              type: 'object',
              properties: {
                offset: { type: 'number' },
                length: { type: 'number' },
                replacement: { type: 'string' }
              }
            }
          }
        },
        required: ['file_path', 'fixes']
      }
    }
  ]
});

// Implement the tools
server.on('get_diagnostics', async (params) => {
  const { file_path } = params;
  // Here you would implement the actual Flutter diagnostics
  // For now, we'll return a mock response
  return {
    diagnostics: [
      {
        severity: 'info',
        message: 'Mock diagnostic message',
        location: {
          file: file_path,
          offset: 0,
          length: 10
        }
      }
    ]
  };
});

server.on('apply_fixes', async (params) => {
  const { file_path, fixes } = params;
  // Here you would implement the actual fix application
  // For now, we'll return a mock response
  return {
    success: true,
    message: `Applied ${fixes.length} fixes to ${file_path}`
  };
});

// Start the server
const port = process.env.MCP_SERVER_PORT || 3032;
server.listen(port, () => {
  console.log(`Flutter Tools MCP Server running on port ${port}`);
}); 