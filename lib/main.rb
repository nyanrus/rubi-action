# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'gha/gha_plugin'
require_relative 'plugin/language_plugin'

api = GHA::API.new_api
api.load_plugins([GHA::Plugin::LanguagePlugin.create_language_plugin])

workflow = api.workflow "my-workflow" do
  on "push", branches: ["main"]

  job "build" do
    runs_on "ubuntu-latest"

    python_result = python "Build Python", "scripts/build.py"
    case python_result
    when Result::Failure
      puts "Error: #{python_result.error}"
    end

    ruby_result = ruby "Build Ruby", "scripts/build.rb"
    case ruby_result
    when Result::Failure
      puts "Error: #{ruby_result.error}"
    end

    python_raw "Python Raw Block", <<~PYTHON
      # This is where syntax completion should work for python (raw block)
      print("hello from python block")
    PYTHON

    ruby_raw "Ruby a Block", <<~RUBY
      # This is where syntax completion should work for ruby (raw block)
      puts "hello from ruby block"
    RUBY
  end
end

puts GHA::Core.to_yaml(workflow)