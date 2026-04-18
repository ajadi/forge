# Domain-Specific Agent Examples

> **WARNING:** These are EXAMPLES only. Replace all placeholder values (`<SERVER_IP>`, `<your domain>`, etc.) with your actual project data before use. Never commit real IPs, credentials, or infrastructure details to a shared template.

These agents are NOT part of the Forge template. They are examples of domain-specific agents (VPN/network domain).

Use them as reference when creating your own domain agents:
- Copy the format (frontmatter, description, tools, model)
- Adapt the prompt body to your domain
- Place in your project's `.claude/agents/` directory
- Add matching commands in `.claude/commands/` if needed

## Files

- `vpn-engineer.md` — VPN protocol configuration, client setup
- `network-engineer.md` — Linux networking, firewall, DNS, SSL
- `censorship-bypass-analyst.md` — Blocking patterns, protocol survival
- `traffic-obfuscation-expert.md` — DPI evasion, TLS fingerprinting
- `rf-blocks-intel.md` — Blocking intelligence scraping
