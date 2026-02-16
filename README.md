# Rails Complete

A blog-style demo app built with Rails 8.1 and PostgreSQL. It supports full CRUD for articles and comments, background job processing with Sidekiq, and real-time updates with Hotwire.

## Features

- **Articles** with title, body, and author — paginated index, full CRUD, and JSON API
- **Comments** on articles — full CRUD and JSON API
- **Background jobs** via Sidekiq — article processing and email notifications triggered on article creation
- **Hotwire** (Turbo + Stimulus) for modern, SPA-like interactions
- **Solid Cache, Solid Queue, and Solid Cable** for PostgreSQL-backed caching, queueing, and Action Cable in production

## Prerequisites

- Ruby 3.2.2
- PostgreSQL
- Redis (required for Sidekiq in production)

## Getting started

1. Install dependencies:

   ```sh
   bundle install
   ```

2. Set up the database:

   ```sh
   bin/rails db:create db:migrate
   ```

3. Seed sample data (20 articles with comments):

   ```sh
   bin/rails db:seed
   ```

4. Start the app:

   ```sh
   bin/rails server
   ```

   Then visit [http://localhost:3000](http://localhost:3000).

To run the Sidekiq worker alongside the web server, use the Procfile:

```sh
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | Yes (production) | PostgreSQL connection string |
| `REDIS_URL` | Yes (production) | Redis connection string for Sidekiq |
| `RAILS_MAX_THREADS` | No | Puma thread count (default: `3`) |
| `WEB_CONCURRENCY` | No | Puma worker count |
| `RAILS_LOG_LEVEL` | No | Log level (default: `info`) |

## Running tests

```sh
bin/rails test
```

## Project structure

| Path | Description |
|---|---|
| `app/models/article.rb` | Article model with comments association and background job hooks |
| `app/models/comment.rb` | Comment model belonging to an article |
| `app/jobs/process_article_job.rb` | Simulates article processing and sets `processed_at` |
| `app/jobs/send_email_job.rb` | Simulates email notification on article creation |
| `config/sidekiq.yml` | Sidekiq configuration (queues: `default`, `mailers`) |
