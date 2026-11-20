# frozen_string_literal: true

require "rails_helper"

# Solid Queue takes each worker's `queues` as a list and doesn't split strings
# on commas: `queues: "critical,*"` silently became one queue named
# "critical,*", and production processed no job at all until 2026-11-20.
RSpec.describe "config/queue.yml" do
  let(:workers) do
    config = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/queue.yml"))
    config.fetch("production").fetch("workers")
  end

  it "lists every worker's queues as separate names" do
    workers.each do |worker|
      queues = worker.fetch("queues")

      expect(queues).to be_an(Array)
      expect(queues).to all(match(/\A[^,\s]+\z/))
    end
  end

  it "has a worker for every queue the app's jobs use" do
    selectors = workers.flat_map { |worker| worker.fetch("queues") }
    covered = ->(queue) { selectors.any? { |s| s == "*" || s == queue || (s.end_with?("*") && queue.start_with?(s.chomp("*"))) } }

    Rails.application.eager_load!
    used = ApplicationJob.descendants.map { |job| job.new.queue_name } + %w[default solid_queue_recurring]

    expect(used.uniq.reject(&covered)).to be_empty
  end
end
