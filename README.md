# Balance

Balance is an accounting platform for maintaining reliable personal and business books through a controlled, auditable ledger. It combines conventional double-entry accounting with an AI-assisted workflow that prepares reviewable proposals without bypassing accounting controls.

## Core capabilities

- Personal and business workspaces with purpose-built charts of accounts.
- Balanced journal entries with immutable posted lines and explicit reversals.
- Customer records, account management, reporting, and transaction history.
- AI-assisted account and journal-entry proposals that require user review before posting.
- Deterministic validation and transactional persistence at the accounting boundary.

## System guarantees

| Component | Responsibility |
| --- | --- |
| Accounting engine | Validates journal structure, debit and credit balance, account behaviour, and permitted relationships. |
| Posting service | Persists validated entries atomically within a database transaction. |
| Ledger | Preserves posted entries and lines as immutable financial records; corrections use explicit reversals. |
| AI agent | Interprets requests and prepares proposals while remaining subject to catalog, grounding, and ledger validation. |
| Review workflow | Requires proposed accounts and journal entries to be approved or dismissed before they affect the books. |

The model assists with interpretation. The accounting engine remains the enforcement layer and is the final authority on whether an entry is structurally valid.

## Local development

### Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) or Docker Engine with the Compose plugin.
- An OpenAI-compatible model provider when exercising AI features.

### Start the application

From the repository root:

```sh
docker compose up --build
```

Docker starts PostgreSQL, prepares the development databases, and launches Rails with live reload. Open [http://localhost:8080](http://localhost:8080).

Stop the environment with:

```sh
docker compose down
```

The database volume is retained between restarts. Run `docker compose down --volumes` only when intentionally resetting local data.

## AI provider configuration

Balance defaults to an OpenAI-compatible [LM Studio](https://lmstudio.ai/) server at `http://host.docker.internal:1234/v1`.

To configure another compatible provider:

```sh
cp .env.example .env
```

Set the applicable values:

```dotenv
OPENAI_API_BASE=http://host.docker.internal:1234/v1
OPENAI_API_KEY=your-api-key
OPENAI_MODEL=your-model-name
```

Never commit `.env`, `RAILS_MASTER_KEY`, API credentials, production data, or generated secrets.

## Production image validation

To validate the production container locally, provide `RAILS_MASTER_KEY` through `.env`, then run:

```sh
docker compose --profile prod up --build
```

This workflow validates the production image locally; it is not a production deployment procedure.

## Engineering standards

Changes must preserve ledger invariants, authorization boundaries, workspace isolation, proposal review, and transactional posting. Tests, static analysis, security checks, migrations, and operational impact must be addressed before release.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and review requirements.

## License

Balance is distributed under the terms in [COMMERCIAL-LICENSE.md](COMMERCIAL-LICENSE.md).
