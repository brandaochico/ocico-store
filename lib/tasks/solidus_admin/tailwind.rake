# frozen_string_literal: true

require "digest"
require "fileutils"
require "net/http"

# solidus_admin's stylesheet is written for Tailwind v3: a JS config preset
# (config/solidus_admin/tailwind.config.js) with four plugins, and @tailwind
# directives. The tailwindcss-ruby gem only ships v4 now, which ignores that
# config — the build "succeeds" but emits ~15 KB of stray utilities with no
# preflight and none of the admin's theme, leaving the new admin unstyled.
#
# So this task runs Tailwind's official v3 standalone CLI instead, pinned and
# checksum-verified, downloaded once into tmp/. The standalone build bundles
# exactly the plugins solidus_admin requires (forms, typography, aspect-ratio,
# container-queries). The storefront keeps building with v4 through
# tailwindcss-rails; only this file uses v3. Re-pin when bumping solidus_admin
# if its config ever moves to v4.
module SolidusAdminTailwind
  VERSION = "3.4.17"

  # From the release's sha256sums.txt.
  CHECKSUMS = {
    "linux-x64" => "7d24f7fa191d2193b78cd5f5a42a6093e14409521908529f42d80b11fde1f1d4",
    "linux-arm64" => "69b1378b8133192d7d2feb12a116fa12d035594f58db3eff215879e4ad8cf39b",
    "macos-x64" => "6cbdad74be776c087ffa5e9a057512c54898f9fe8828d3362212dfe32fc933a3",
    "macos-arm64" => "a1d0c7985759accca0bf12e51ac1dcbf0f6cf2fffb62e6e0f62d091c477a10a3"
  }.freeze

  module_function

  def platform
    os = case RbConfig::CONFIG["host_os"]
    when /linux/ then "linux"
    when /darwin/ then "macos"
    else abort "solidus_admin:tailwindcss: no Tailwind v3 binary for #{RbConfig::CONFIG["host_os"]}"
    end
    cpu = RbConfig::CONFIG["host_cpu"].match?(/aarch64|arm64/) ? "arm64" : "x64"
    "#{os}-#{cpu}"
  end

  def executable
    path = Rails.root.join("tmp/tailwindcss-v#{VERSION}/tailwindcss-#{platform}")
    download(path) unless path.exist? && Digest::SHA256.file(path).hexdigest == CHECKSUMS.fetch(platform)
    path
  end

  def download(path)
    url = "https://github.com/tailwindlabs/tailwindcss/releases/download/v#{VERSION}/tailwindcss-#{platform}"
    puts "Downloading Tailwind CSS v#{VERSION} (#{platform}) for solidus_admin..."
    body = fetch(URI(url))

    actual = Digest::SHA256.hexdigest(body)
    expected = CHECKSUMS.fetch(platform)
    abort "solidus_admin:tailwindcss: checksum mismatch for #{url} (got #{actual}, expected #{expected})" unless actual == expected

    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, body)
    File.chmod(0o755, path)
  end

  def fetch(uri, redirects = 5)
    response = Net::HTTP.get_response(uri)
    case response
    when Net::HTTPRedirection
      abort "solidus_admin:tailwindcss: too many redirects" if redirects.zero?
      fetch(URI(response["location"]), redirects - 1)
    when Net::HTTPSuccess then response.body
    else abort "solidus_admin:tailwindcss: download failed (HTTP #{response.code}) from #{uri}"
    end
  end

  def command
    root = Rails.root
    [
      executable.to_s,
      "--config", root.join("config/solidus_admin/tailwind.config.js").to_s,
      "--input", root.join("app/assets/stylesheets/solidus_admin/application.tailwind.css").to_s,
      "--output", root.join("app/assets/builds/solidus_admin/tailwind.css").to_s
    ]
  end
end

namespace :solidus_admin do
  namespace :tailwindcss do
    desc "Build solidus_admin's Tailwind CSS (Tailwind v3, see lib/tasks/solidus_admin/tailwind.rake)"
    task :build do
      sh SolidusAdminTailwind.command.shelljoin
    end

    desc "Watch solidus_admin's Tailwind CSS"
    task :watch do
      sh (SolidusAdminTailwind.command + [ "--watch" ]).shelljoin
    end
  end
end

# Attach Tailwind CSS build to other tasks.
%w[
  assets:precompile
  test:prepare
  spec:prepare
  db:test:prepare
].each do |task_name|
  next unless Rake::Task.task_defined?(task_name)

  Rake::Task[task_name].enhance([ "solidus_admin:tailwindcss:build" ])
end
