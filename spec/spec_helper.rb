# frozen_string_literal: true

require 'bundler/setup'
require 'dspy'
require 'vcr'
require 'webmock/rspec'
require 'dotenv/load'

# Load lib files for testing
Dir[File.join(__dir__, '..', 'lib', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end

# VCR Configuration
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  
  # Redact sensitive API keys
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV.fetch('OPENAI_API_KEY', nil) }
  config.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV.fetch('ANTHROPIC_API_KEY', nil) }
  config.filter_sensitive_data('<GITHUB_TOKEN>') { ENV.fetch('GITHUB_TOKEN', nil) }
  
  # Also redact from headers
  config.before_record do |interaction|
    # Redact Authorization headers
    if interaction.request.headers['Authorization']
      interaction.request.headers['Authorization'] = ['Bearer <REDACTED>']
    end
    
    # Redact API keys from request bodies
    if interaction.request.body
      body = interaction.request.body
      body.gsub!(/sk-[a-zA-Z0-9]+/, '<OPENAI_API_KEY>')
      body.gsub!(/sk-ant-[a-zA-Z0-9]+/, '<ANTHROPIC_API_KEY>')
    end
    
    # Redact from response if needed
    if interaction.response.body
      body = interaction.response.body
      # Sometimes API keys might appear in error messages
      body.gsub!(/sk-[a-zA-Z0-9]+/, '<OPENAI_API_KEY>')
      body.gsub!(/sk-ant-[a-zA-Z0-9]+/, '<ANTHROPIC_API_KEY>')
    end
  end
  
  # Default cassette options
  config.default_cassette_options = {
    record: :new_episodes,  # Only record new requests
    match_requests_on: [:method, :uri, :body]
  }
end

# DSPy Configuration for tests
RSpec.configure do |config|
  config.before(:each) do
    # Configure DSPy for tests
    DSPy.configure do |dspy_config|
      # Use test models by default
      dspy_config.lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV.fetch('OPENAI_API_KEY', 'test-key'))
      
      # Enable instrumentation for testing
      # dspy_config.instrumentation.enabled = true
      # dspy_config.instrumentation.subscribers = [:logger]
    end
  end
end