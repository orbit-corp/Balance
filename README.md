# Stubby

A cash-basis bookkeeping ledger for small Nigerian businesses selling over WhatsApp/Instagram/Facebook.
Track sales, expenses, and customers; see income/expense/profit totals at a glance. NGN only.

## WhatsApp integration ENV

| Variable | Purpose |
| --- | --- |
| `WHATSAPP_VERIFY_TOKEN` | Shared secret used to verify Meta's webhook subscription handshake (`GET webhooks/whatsapp`). |
| `WHATSAPP_APP_SECRET` | App secret used to verify the `X-Hub-Signature-256` header on incoming webhook payloads. If blank, signature verification is skipped (dev only). |
| `WHATSAPP_ACCESS_TOKEN` | Bearer token used to call the Graph API to send messages. If blank, outbound sends are skipped and logged. |
| `WHATSAPP_PHONE_NUMBER_ID` | The business phone number ID used as the sender for outbound Graph API calls. |
| `WHATSAPP_BUSINESS_NUMBER` | The WhatsApp number end users message to link their account, used to build `wa.me` deep links. |
