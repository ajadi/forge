# ssh-mcp-ft

A minimal MCP (Model Context Protocol) **stdio** server that exposes SSH control of a
remote host **plus file transfer over SFTP**. It is a drop-in superset of `ssh-mcp`:
the `exec` / `sudo_exec` tools behave the same, and it adds `upload_file` /
`download_file` so an agent can move tarballs, build artifacts and configs to/from the
server without base64-over-exec hacks.

## Tools

| Tool | Args | Purpose |
|------|------|---------|
| `exec` | `command` | Run a shell command, return stdout/stderr/exit code |
| `sudo_exec` | `command` | Run with `sudo -S` (uses the SSH password) |
| `upload_file` | `localPath`, `remotePath` | SFTP put — local → remote |
| `download_file` | `remotePath`, `localPath` | SFTP get — remote → local |

## Install

```bash
cd ssh-mcp-ft
npm install        # @modelcontextprotocol/sdk, ssh2, zod
```

## Wire into `.mcp.json`

```json
{
  "mcpServers": {
    "my-server": {
      "type": "stdio",
      "command": "node",
      "args": [
        "/abs/path/to/ssh-mcp-ft/index.js",
        "--host=YOUR_HOST",
        "--user=YOUR_USER",
        "--password=YOUR_PASSWORD"
      ]
    }
  }
}
```

Args: `--host=` and `--user=` are required; `--password=` and `--port=` (default 22)
are optional. Each tool call opens a fresh SSH connection and closes it on completion.

## Security

`.mcp.json` holds the password in plaintext — keep it gitignored (never commit it).
Built for trusted-LAN / lab deployment, not public exposure.

## Why this exists

`ssh-mcp` only exposes `exec`/`sudo-exec` and caps command length (`maxChars`, default
1000), so transferring a file by piping base64 through `exec` is impractical. This server
adds real SFTP transfer, which is what you want for deploying a built project (e.g.
`upload_file` a `git archive` tarball, then `exec` `docker build` on the host).
