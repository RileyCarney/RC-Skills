# Agent in a box
Source: https://docs.boxlite.ai/agent-in-box/index

Put a whole coding agent inside a microVM, where it can read, write, and execute freely without touching your host.

The other pattern. In [Agent tools](/agent-tools/index) your agent runs on the host and reaches into a box; here the **agent itself runs inside the box**, and the box is its whole world.

That trade is the point: the agent gets a real filesystem, a real shell, and real network access, and none of it is yours.

Every page below installs one agent CLI, gives it credentials, and drives it — all verified end to end.

## In this section

> [card] [Claude Code](/agent-in-box/run-claude-code)
>
> Anthropic's CLI, in a box where it can edit and execute freely. **The flagship.**

> [card] [Codex](/agent-in-box/run-codex)
>
> OpenAI's Codex CLI, executing without host access.

> [card] [Pi](/agent-in-box/run-pi)
>
> The Pi coding agent, reading and writing inside the box.

> [card] [OpenCode](/agent-in-box/run-opencode)
>
> OpenCode, with its provider configured without writing secrets to disk.

> [card] [Hermes](/agent-in-box/run-hermes)
>
> Hermes from its official image — one-shot prompts or a session.

## Which page do I want?

| You are asking | Page |
| - | - |
| Which agent should I start with? | [run claude code](/agent-in-box/run-claude-code) |
| How do I give the agent an API key safely? | [secrets and security](/manage-sandbox/secrets-and-security) |
| How do I stop the agent reaching the internet? | [network access](/manage-sandbox/network-access) |
| How do I keep its work after the box is gone? | [volumes](/manage-sandbox/volumes) |
