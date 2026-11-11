# WebSockets with Python — Python Web Development

You are an expert in building real-time WebSocket applications in Python using FastAPI, Django Channels, and the standalone websockets library.

## Core Philosophy

### Overview

WebSockets provide full-duplex communication between client and server over a single TCP connection. Python supports WebSockets through several approaches: FastAPI's built-in WebSocket support (via Starlette), Django Channels for adding async protocols to Django, and the standalone `websockets` library for custom servers and clients.

## Setup & Configuration

### FastAPI WebSockets

```bash
pip install fastapi uvicorn
```

No extra configuration needed; FastAPI includes WebSocket support via Starlette.

### Django Channels

```bash
pip install channels channels-redis daphne
```

```python
# settings.py
INSTALLED_APPS = [
    "daphne",
    "channels",
    # ...
]

ASGI_APPLICATION = "proj.asgi.application"

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [("localhost", 6379)],
        },
    },
}
```

```python
# proj/asgi.py
import os
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "proj.settings")
django_asgi_app = get_asgi_application()

from chat.routing import websocket_urlpatterns  # noqa: E402

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)
    ),
})
```

### Standalone websockets Library

```bash
pip install websockets
```

## Core Patterns

### FastAPI WebSocket Endpoint

```python
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from typing import Dict, Set
import json

app = FastAPI()


class ConnectionManager:
    def __init__(self):
        self.active: Dict[str, Set[WebSocket]] = {}

    async def connect(self, room: str, websocket: WebSocket):
        await websocket.accept()
        self.active.setdefault(room, set()).add(websocket)

    def disconnect(self, room: str, websocket: WebSocket):
        self.active.get(room, set()).discard(websocket)

    async def broadcast(self, room: str, message: dict):
        payload = json.dumps(message)
        dead = []
        for ws in self.active.get(room, set()):
            try:
                await ws.send_text(payload)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(room, ws)


manager = ConnectionManager()


@app.websocket("/ws/chat/{room}")
async def chat_endpoint(websocket: WebSocket, room: str):
    await manager.connect(room, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            await manager.broadcast(room, {
                "user": data.get("user", "anonymous"),
                "message": data["message"],
            })
    except WebSocketDisconnect:
        manager.disconnect(room, websocket)
        await manager.broadcast(room, {
            "system": "A user has left the chat.",
        })
```

### Django Channels Consumer

```python
# chat/consumers.py
import json
from channels.generic.websocket import AsyncJsonWebSocketConsumer


class ChatConsumer(AsyncJsonWebSocketConsumer):
    async def connect(self):
        self.room_name = self.scope["url_route"]["kwargs"]["room"]
        self.room_group = f"chat_{self.room_name}"

        await self.channel_layer.group_add(self.room_group, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.room_group, self.channel_name
        )

    async def receive_json(self, content):
        user = self.scope["user"]
        await self.channel_layer.group_send(
            self.room_group,
            {
                "type": "chat.message",
                "user": user.username if user.is_authenticated else "anonymous",
                "message": content["message"],
            },
        )

    async def chat_message(self, event):
        await self.send_json({
            "user": event["user"],
            "message": event["message"],
        })
```

```python
# chat/routing.py
from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r"ws/chat/(?P<room>\w+)/$", consumers.ChatConsumer.as_asgi()),
]
```

### Standalone websockets Server

```python
import asyncio
import json
import websockets
from websockets.server import serve

CONNECTIONS: dict[str, set] = {}


async def handler(websocket):
    room = websocket.path.strip("/")
    CONNECTIONS.setdefault(room, set()).add(websocket)
    try:
        async for raw in websocket:
            data = json.loads(raw)
            payload = json.dumps({
                "user": data.get("user", "anon"),
                "message": data["message"],
            })
            targets = CONNECTIONS.get(room, set()) - {websocket}
            websockets.broadcast(targets, payload)
    finally:
        CONNECTIONS.get(room, set()).discard(websocket)


async def main():
    async with serve(handler, "0.0.0.0", 8765):
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    asyncio.run(main())
```

### Authentication

```python
# FastAPI WebSocket auth via query parameter
from fastapi import WebSocket, Query, status


async def get_ws_user(websocket: WebSocket, token: str = Query(...)):
    user = verify_token(token)
    if not user:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None
    return user


@app.websocket("/ws/notifications")
async def notifications(websocket: WebSocket, token: str = Query(...)):
    user = await get_ws_user(websocket, token)
    if not user:
        return
    await websocket.accept()
    # ...
```

### Heartbeat and Reconnection

```python
import asyncio
from fastapi import WebSocket, WebSocketDisconnect


@app.websocket("/ws/stream")
async def stream(websocket: WebSocket):
    await websocket.accept()

    async def send_pings():
        while True:
            try:
                await asyncio.sleep(30)
                await websocket.send_json({"type": "ping"})
            except Exception:
                break

    ping_task = asyncio.create_task(send_pings())
    try:
        while True:
            data = await websocket.receive_json()
            if data.get("type") == "pong":
                continue
            # handle real messages
            await websocket.send_json({"type": "ack", "id": data.get("id")})
    except WebSocketDisconnect:
        pass
    finally:
        ping_task.cancel()
```

### Client-Side JavaScript

```javascript
class ReconnectingWebSocket {
  constructor(url, protocols = []) {
    this.url = url;
    this.protocols = protocols;
    this.reconnectDelay = 1000;
    this.maxDelay = 30000;
    this.handlers = { message: [], open: [], close: [] };
    this.connect();
  }

  connect() {
    this.ws = new WebSocket(this.url, this.protocols);
    this.ws.onopen = () => {
      this.reconnectDelay = 1000;
      this.handlers.open.forEach((h) => h());
    };
    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.type === "ping") {
        this.ws.send(JSON.stringify({ type: "pong" }));
        return;
      }
      this.handlers.message.forEach((h) => h(data));
    };
    this.ws.onclose = () => {
      this.handlers.close.forEach((h) => h());
      setTimeout(() => this.connect(), this.reconnectDelay);
      this.reconnectDelay = Math.min(this.reconnectDelay * 2, this.maxDelay);
    };
  }

  send(data) {
    if (this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(data));
    }
  }

  on(event, handler) {
    this.handlers[event]?.push(handler);
  }
}
```

### Scaling with Redis Pub/Sub

```python
import aioredis
import asyncio
import json


class RedisPubSubManager:
    def __init__(self, redis_url="redis://localhost"):
        self.redis_url = redis_url
        self.pubsub = None

    async def connect(self):
        self.redis = await aioredis.from_url(self.redis_url)
        self.pubsub = self.redis.pubsub()

    async def subscribe(self, channel: str, callback):
        await self.pubsub.subscribe(channel)
        asyncio.create_task(self._reader(callback))

    async def publish(self, channel: str, message: dict):
        await self.redis.publish(channel, json.dumps(message))

    async def _reader(self, callback):
        async for message in self.pubsub.listen():
            if message["type"] == "message":
                data = json.loads(message["data"])
                await callback(data)
```

## Best Practices

- Always handle `WebSocketDisconnect` exceptions. Clients disconnect at any time and unhandled exceptions crash the handler.
- Use JSON as the message format with a `type` field for routing: `{"type": "chat.message", "payload": {...}}`.
- Implement heartbeat pings on the server side to detect dead connections early. Close connections that miss multiple pongs.
- For multi-server deployments, use Redis pub/sub or Django Channels' channel layer to broadcast messages across processes.
- Authenticate during the WebSocket handshake (via query parameter or cookie), not after the connection opens.
- Limit message size with `max_size` to prevent memory exhaustion from malicious clients.

## Common Pitfalls

- Broadcasting by iterating over a set while connections disconnect concurrently. Always collect dead connections and remove them after iteration.
- Not running an ASGI server. WebSockets require an ASGI server like Uvicorn or Daphne. WSGI servers (Gunicorn with sync workers) do not support WebSockets.
- Using Django Channels without a channel layer (Redis). Without it, `group_send` only works within a single process and messages are lost in multi-worker deployments.
- Forgetting to `await websocket.accept()` before sending data. The connection is not open until `accept()` completes.
- Blocking the event loop with synchronous database calls inside a WebSocket handler. Use async database drivers or run sync code with `asyncio.to_thread()`.
- Not implementing client-side reconnection. Network interruptions are inevitable; clients must reconnect with exponential backoff.
## Anti-Patterns

**Over-engineering for hypothetical scale.** Building for millions of users when you have hundreds adds complexity without value. Solve today's problems first.

**Ignoring the existing ecosystem.** Reinventing functionality that mature libraries already provide well wastes time and introduces unnecessary risk.

**Premature abstraction.** Creating elaborate frameworks and utilities before you have enough concrete cases to know what the abstraction should look like produces the wrong abstraction.

**Neglecting error handling at boundaries.** Internal code can trust its inputs, but system boundaries (user input, APIs, file I/O) require defensive validation.

**Skipping documentation for obvious code.** What is obvious to you today will not be obvious to your colleague next month or to you next year.
