# Give your service a fixed public domain
Source: https://docs.boxlite.ai/cloud/domains

Reach a service inside a Cloud box through a named HTTPS address, and keep that address when you move to another box.

Give a web app, API, or agent service a public address such as `https://my-service.boxliteapp.com`. Visitors use that address while BoxLite routes requests to a port inside your box.

The domain belongs to your organization. You can move it to another box without changing the address your clients use.

> [!NOTE]
>
> This guide uses a subdomain you choose under BoxLite's domain. Attaching a domain you own, such as `api.your-company.com`, is not supported by this flow. No DNS records or TLS certificates need to be configured for the BoxLite-provided address.

## Before you start

Install the latest CLI in your local terminal:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
curl -fsSL https://sh.boxlite.ai | sh
```

Create an [API key](/cloud/api-keys) in the [console](https://app.boxlite.ai), then sign in:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
boxlite --context app auth login \
  --url https://api.boxlite.ai --method api-key
```

Paste your key at the prompt. `app` is the saved context used throughout this guide. Use the same organization in the console and CLI.

## Publish your service

**1. Reserve your domain**

In the console, open **Domains**, then **Request domain**. Enter a short name, such as `my-service`, and review the **Full domain** preview before submitting.

Choose an available name using lowercase letters, digits, and hyphens. The page shows your organization's name-length requirement and remaining allowance.

Copy the full hostname into your terminal, replacing the placeholder below. Include neither `https://` nor a port:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
DOMAIN='<YOUR_FULL_DOMAIN>'
```

For example, if you reserved `my-service`, the production hostname is `my-service.boxliteapp.com`. Use the hostname actually returned by your environment.

Already have a domain? Reuse it instead of requesting another:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
boxlite --context app domain ls
```

> [!NOTE]
>
> Reserving a name uses your organization's domain allowance. Unbinding it later keeps the name reserved and does not free that allowance.

**2. Choose the service to expose**

> [tab] Existing service
>
> Set the box ID or name and the port your service listens on **inside the box**:
>
> ```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
> BOX='<YOUR_BOX_ID_OR_NAME>'
> PORT=29090
> boxlite --context app start "$BOX"
> ```
>
> Replace `29090` with your service's port. The service must listen on `0.0.0.0`, rather than only `127.0.0.1`.

> [tab] Try a sample server
>
> Create a box with an HTTP server as its saved startup command:
>
> ```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
> BOX=$(boxlite --context app create \
>   --name domain-demo \
>   --auto-stop 0 --auto-delete 0 \
>   python:alpine python -m http.server 29090 --bind 0.0.0.0)
> PORT=29090
> boxlite --context app start "$BOX"
> ```
>
> The sample serves a directory listing. `--auto-stop 0` keeps it running until you stop it; request-triggered startup is optional.

**3. Open the port and bind the domain**

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
boxlite --context app network inbound "$BOX" enabled
boxlite --context app network tunnel "$BOX" "$PORT"
boxlite --context app domain bind "$DOMAIN" \
  --type box --box "$BOX" --port "$PORT"
```

The tunnel command registers the port for public access and prints its generated URL. The bind command gives that port your chosen hostname and prints its HTTPS URL.

All three pieces are required: inbound access, a public tunnel for the port, and the domain binding. Binding alone does not make a service public.

This is a public endpoint. If your service needs sign-in or API authentication, enforce it in the application.

**4. Open your fixed URL**

Open `https://<YOUR_FULL_DOMAIN>` in your browser, or request it from your terminal:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
curl --fail --show-error \
  -H 'X-BoxLite-Skip-Preview-Warning: true' \
  "https://$DOMAIN/"
```

The header skips the preview notice for scripted requests; it does not grant access or bypass your application's authentication.

You should receive your service's response. For the sample server, look for **Directory listing for /**. Share this HTTPS address with your clients; they do not need the box ID or internal port.

## Move the service without changing its URL

Start your service on the replacement box first. Then open its port and bind the **same domain** to it:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
NEW_BOX='<YOUR_REPLACEMENT_BOX_ID_OR_NAME>'
NEW_PORT=29090
boxlite --context app start "$NEW_BOX"
boxlite --context app network inbound "$NEW_BOX" enabled
boxlite --context app network tunnel "$NEW_BOX" "$NEW_PORT"
boxlite --context app domain bind "$DOMAIN" \
  --type box --box "$NEW_BOX" --port "$NEW_PORT"
```

New requests to the fixed URL now reach the replacement service. You do not need to unbind first or reserve another name.

This changes routing; it does not copy files or application state. Prepare any data the new service needs before switching. See [Data across boxes](/cloud/data-across-boxes).

## Optional: wake the box on a request

You can keep the service running continuously, or let the box stop between requests. The fixed domain works with either approach.

For request-triggered startup, leave **Wake on access** enabled and save your service as the box's startup command. The sample above already does this. A server started only in an interactive session may not return after a restart.

To try it, stop the box, wait until the console shows **Stopped**, and request the same URL:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
boxlite --context app stop "$BOX"
# Wait for Stopped in the console before sending this request.
curl --fail --show-error \
  -H 'X-BoxLite-Skip-Preview-Warning: true' \
  "https://$DOMAIN/"
```

The request starts the box and reaches the service. Allow extra time for startup on the first request.

For automatic idle stopping, choose a nonzero `--auto-stop` interval when creating the box. See [Stop when idle](/cloud/box-lifecycle#stop-when-idle) and [Wake on access](/cloud/box-lifecycle#wake-on-access).

## Unbind or close public access

To stop routing the domain while keeping it for later:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
boxlite --context app domain unbind "$DOMAIN"
boxlite --context app domain ls
```

New requests to the domain return `404`. The name remains reserved, and the list shows no target.

**Unbinding leaves the generated tunnel URL accessible.** To close public access to that port as well:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
boxlite --context app network tunnel --revoke "$BOX" "$PORT"
```

If you created the sample box and no longer need it, delete it:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
boxlite --context app rm --force "$BOX"
```

Deleting a box does not release its domain or automatically clear its binding. Unbind or point the domain at another box explicitly.

## Troubleshooting

| Symptom | What to check |
| - | - |
| The CLI does not recognize `domain` | Install the latest CLI and check `boxlite domain --help`. |
| `domain_not_owned` when binding | Reserve the name first, use its full hostname, and select the same organization and environment in the CLI. |
| The domain allowance is full | Reuse a held domain from `domain ls`; unbinding does not free a slot. |
| The domain returns `404` | Check its binding, inbound access, and the port's public tunnel. Private or revoked tunnels do not serve named domains. |
| The request fails even though the binding exists | Confirm the service is running on the bound port and listening on `0.0.0.0`. |
| A stopped box does not serve the next request | Check Wake on access and the saved service startup command. |
| The domain reaches the wrong service | Inspect `domain ls` and bind it to the intended box and port. |
