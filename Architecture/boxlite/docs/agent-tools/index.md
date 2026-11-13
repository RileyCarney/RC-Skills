# Agent tools
Source: https://docs.boxlite.ai/agent-tools/index

The capabilities an agent calls: run code, run any command, drive a terminal, a browser, or a desktop, and expose it all over MCP.

These are the things an agent *does* inside a box. Each page owns one capability, its parameters, and a runnable example.

If the agent should live **inside** the box rather than call into it, see [Agent in a box](/agent-in-box/index) instead.

## In this section

> [card] [Run Python](/agent-tools/code-execution-python)
>
> `CodeBox` and stdout back — the shortest path from an LLM's output to a result.

> [card] [Run any command](/agent-tools/code-execution-any-language)
>
> Any shell command or executable, in any language, in a disposable microVM.

> [card] [Pseudo-terminal](/agent-tools/pseudo-terminal)
>
> A real interactive terminal, like `docker exec -it`.

> [card] [Browser automation](/agent-tools/browser-automation)
>
> A real Chromium, Firefox, or WebKit, exposed over CDP.

> [card] [Computer use](/agent-tools/computer-use)
>
> A full Linux desktop the agent can see and click.

> [card] [GitHub operations](/agent-tools/github-operations)
>
> Clone, commit, push, and open pull requests from inside a sandbox.

> [card] [Drive from an agent loop](/agent-tools/drive-from-agent-loop)
>
> One safe door: the model proposes, your loop executes.

> [card] [MCP server](/agent-tools/mcp-server)
>
> Expose sandboxed execution to any Model Context Protocol client.

## Which page do I want?

| You are asking | Page |
| - | - |
| Run code an LLM just wrote | [code execution python](/agent-tools/code-execution-python) |
| Run a build, a test suite, or any binary | [code execution any language](/agent-tools/code-execution-any-language) |
| Keep a shell session open across turns | [pseudo terminal](/agent-tools/pseudo-terminal) |
| Let the agent browse the web | [browser automation](/agent-tools/browser-automation) |
| Let the agent use a GUI | [computer use](/agent-tools/computer-use) |
| Wire this into an existing tool-calling loop | [drive from agent loop](/agent-tools/drive-from-agent-loop) |
| Expose it to Claude Desktop or another MCP client | [mcp server](/agent-tools/mcp-server) |
