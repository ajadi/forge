#!/usr/bin/env node
// ssh-mcp-ft — SSH MCP server with file-transfer (SFTP) tools.
// Adds upload_file / download_file on top of exec / sudo_exec.
//
// Usage (in .mcp.json):
//   "command": "node",
//   "args": ["/abs/path/to/ssh-mcp-ft/index.js",
//            "--host=YOUR_HOST", "--user=YOUR_USER", "--password=..."]
//
// Args: --host= --user= --password= [--port=22]
// Each tool call opens a fresh SSH connection and closes it when done.

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { Client } from 'ssh2';

// ---- parse args ------------------------------------------------------------
const argOf = (name, def) => {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : def;
};
const HOST = argOf('host');
const USER = argOf('user');
const PASSWORD = argOf('password');
const PORT = parseInt(argOf('port', '22'), 10);

if (!HOST || !USER) {
  console.error('ssh-mcp-ft: --host and --user are required');
  process.exit(1);
}

// ---- ssh helpers -----------------------------------------------------------
function connect() {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    conn
      .on('ready', () => resolve(conn))
      .on('error', reject)
      .connect({ host: HOST, port: PORT, username: USER, password: PASSWORD, readyTimeout: 20000 });
  });
}

function runCommand(command) {
  return new Promise((resolve, reject) => {
    connect()
      .then((conn) => {
        conn.exec(command, (err, stream) => {
          if (err) {
            conn.end();
            return reject(err);
          }
          let stdout = '';
          let stderr = '';
          stream
            .on('close', (code) => {
              conn.end();
              resolve({ code, stdout, stderr });
            })
            .on('data', (d) => (stdout += d.toString()))
            .stderr.on('data', (d) => (stderr += d.toString()));
        });
      })
      .catch(reject);
  });
}

// sudo via `sudo -S` reading the password from stdin (works for passwordless too)
function runSudo(command) {
  return new Promise((resolve, reject) => {
    connect()
      .then((conn) => {
        conn.exec(`sudo -S -p '' bash -c ${shellQuote(command)}`, (err, stream) => {
          if (err) {
            conn.end();
            return reject(err);
          }
          let stdout = '';
          let stderr = '';
          stream
            .on('close', (code) => {
              conn.end();
              resolve({ code, stdout, stderr });
            })
            .on('data', (d) => (stdout += d.toString()))
            .stderr.on('data', (d) => (stderr += d.toString()));
          if (PASSWORD) stream.write(PASSWORD + '\n');
        });
      })
      .catch(reject);
  });
}

function shellQuote(s) {
  return `'${String(s).replace(/'/g, `'\\''`)}'`;
}

function sftpPut(localPath, remotePath) {
  return new Promise((resolve, reject) => {
    connect()
      .then((conn) => {
        conn.sftp((err, sftp) => {
          if (err) {
            conn.end();
            return reject(err);
          }
          sftp.fastPut(localPath, remotePath, (e) => {
            conn.end();
            if (e) return reject(e);
            resolve(remotePath);
          });
        });
      })
      .catch(reject);
  });
}

function sftpGet(remotePath, localPath) {
  return new Promise((resolve, reject) => {
    connect()
      .then((conn) => {
        conn.sftp((err, sftp) => {
          if (err) {
            conn.end();
            return reject(err);
          }
          sftp.fastGet(remotePath, localPath, (e) => {
            conn.end();
            if (e) return reject(e);
            resolve(localPath);
          });
        });
      })
      .catch(reject);
  });
}

const text = (s) => ({ content: [{ type: 'text', text: s }] });
const fmt = (r) =>
  text(
    [
      `exit_code: ${r.code}`,
      r.stdout ? `--- stdout ---\n${r.stdout}` : '',
      r.stderr ? `--- stderr ---\n${r.stderr}` : '',
    ]
      .filter(Boolean)
      .join('\n')
  );

// ---- MCP server ------------------------------------------------------------
const server = new McpServer({ name: 'ssh-mcp-ft', version: '1.0.0' });

server.registerTool(
  'exec',
  {
    description: `Run a shell command on ${USER}@${HOST} over SSH and return stdout/stderr/exit code.`,
    inputSchema: { command: z.string().describe('Shell command to execute on the remote host') },
  },
  async ({ command }) => fmt(await runCommand(command))
);

server.registerTool(
  'sudo_exec',
  {
    description: `Run a shell command with sudo on ${USER}@${HOST}. Uses the SSH password for sudo -S.`,
    inputSchema: { command: z.string().describe('Shell command to execute with sudo') },
  },
  async ({ command }) => fmt(await runSudo(command))
);

server.registerTool(
  'upload_file',
  {
    description: `Upload a local file to ${USER}@${HOST} via SFTP. Use for transferring tarballs, configs, build artifacts to the server.`,
    inputSchema: {
      localPath: z.string().describe('Absolute path to the local file to upload'),
      remotePath: z.string().describe('Absolute destination path on the remote host'),
    },
  },
  async ({ localPath, remotePath }) => {
    await sftpPut(localPath, remotePath);
    return text(`uploaded ${localPath} -> ${USER}@${HOST}:${remotePath}`);
  }
);

server.registerTool(
  'download_file',
  {
    description: `Download a file from ${USER}@${HOST} to the local machine via SFTP.`,
    inputSchema: {
      remotePath: z.string().describe('Absolute path of the file on the remote host'),
      localPath: z.string().describe('Absolute local destination path'),
    },
  },
  async ({ remotePath, localPath }) => {
    await sftpGet(remotePath, localPath);
    return text(`downloaded ${USER}@${HOST}:${remotePath} -> ${localPath}`);
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
console.error(`ssh-mcp-ft connected to ${USER}@${HOST}:${PORT}`);
