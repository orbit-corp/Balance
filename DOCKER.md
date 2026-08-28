# Run Balance locally with Docker

Start the application and PostgreSQL:

```sh
docker compose up --build
```

Open [http://localhost:3000](http://localhost:3000). The development stack prepares the primary, queue, and cable databases and starts Rails, Tailwind, and the Solid Queue worker.

Balance uses a local LM Studio server by default. When Docker runs on the same machine, it reaches LM Studio at `http://host.docker.internal:1234/v1`. Override the model endpoint, API key, or model name through environment variables in an untracked `.env` file; start from `.env.example`. Do not commit credentials.

Stop the stack with `docker compose down`. Add `--volumes` only when you intentionally want to remove local PostgreSQL data.
