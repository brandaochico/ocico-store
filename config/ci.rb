# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  # app/assets/builds/*.css is gitignored (build output). Some Rake-task chain
  # builds it automatically for local `bundle exec rspec` runs, but that hasn't
  # proven reliable on a truly fresh checkout (CI) — build it explicitly instead
  # of depending on that.
  step "Build assets", "bin/rails tailwindcss:build solidus_admin:tailwindcss:build"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  # No config/importmap.rb / bin/importmap binstub: solidus_starter_frontend's JS
  # pipeline loads via Sprockets (javascript_include_tag) instead of pinned
  # importmap packages, so there's nothing for `importmap audit` to check yet.
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  # System specs need a real browser driver (not set up yet) and currently also
  # hit a legacy sassc/libsass bug (can't parse modern relative-color CSS syntax
  # pulled in by Rails.application.precompiled_assets during their before(:suite)
  # hook) — both are real setup work for a later phase, not a Fase 0 concern.
  step "Test: RSpec", "bundle exec rspec --exclude-pattern 'spec/system/**/*_spec.rb'"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
