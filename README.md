# cayado

The Rails engine behind Cayado, the vision, roadmap and sermon-alignment
planner for a pastor and their exec team. `cayado-cloud` (hosted, many
churches) and a self-hosted app both mount it.

It has churches, staff accounts (email + password, with a required
authenticator code), tenancy from the Host header (`{slug}.cayado.cloud`, a
verified custom domain, or the only church on a self-hosted install), and
the JSON API under `/api/v1`. Sign-in is Rodauth under `/auth`.

The repo is also a standalone Rails app, so the gem runs its own specs:

```sh
bundle install
bin/rails db:create db:migrate
RAILS_ENV=test bin/rails db:create db:schema:load
bundle exec rspec
```
