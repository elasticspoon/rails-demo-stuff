# frozen_string_literal: true

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'

  gem 'rails'
  gem 'trace_location'
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"
end

require 'action_controller/railtie'

class TestApp < Rails::Application
  config.root = __dir__
  config.hosts << 'example.org'
  config.secret_key_base = 'secret_key_base'

  # config.logger = Logger.new($stdout)
  config.logger = Logger.new(File::NULL)
  Rails.logger  = config.logger

  routes.draw do
    get '/' => 'test#index'
  end
end

class TestController < ActionController::Base
  include Rails.application.routes.url_helpers

  def index
    render plain: 'Home'
  end
end

require 'minitest/autorun'
require 'rack/test'
require 'trace_location'

class BugTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def test_allocations_skipping_router
    repeat_times(100, test_name: 'Skipping rack + router') do
      TestController.action(:index).call(mock_request)
    end
    assert true
  end

  def test_allocations_skipping_rack
    repeat_times(100, test_name: 'Skipping rack') do
      app.routes.call(mock_request)
    end
    assert true
  end

  def test_base_request_allocations
    repeat_times(100, test_name: 'Full request') do
      app.call(mock_request)
    end
    assert true
  end

  # def test_trace_skipping_router
  #   request = mock_request
  #   TraceLocation.trace(format: :log) do
  #     TestController.action(:index).call(request)
  #   end
  #   assert true
  # end

  # def test_trace_skipping_rack
  #   request = mock_request
  #   TraceLocation.trace(format: :log) do
  #     app.routes.call(request)
  #   end
  #   assert true
  # end

  # def test_base_request_trace
  #   request = mock_request
  #   TraceLocation.trace(format: :log) do
  #     app.call(request)
  #   end
  #   assert true
  # end

  private

  def app
    Rails.application
  end

  def repeat_times(times, test_name: nil, &block)
    allocs = (0..times).map { allocations { block.call } }
    allocs = allocs.sort
    puts "#{test_name} allocated #{allocs[allocs.length / 2]} objects".strip
  end

  def allocations
    x = GC.stat(:total_allocated_objects)
    yield
    GC.stat(:total_allocated_objects) - x
  end

  def mock_request
    Rack::MockRequest.env_for('http://example.org', 'HTTP_HOST' => 'example.org')
  end
end
