# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'types'
require_relative '../gha/gha_core'
require_relative 'script_helper'

module GHA
  module Helpers
    module StepFactory
      extend T::Sig

      sig do
        params(
          config: LanguageConfig
        ).returns(T.proc.params(script_content: String, opts: BuilderOptions).returns(Step))
      end
      def self.create_language_helper(config)
        proc do |script_content, opts|
          step_name = opts.name || "Run #{config.name} script"
          s = Core.new_step(StepOptions.new(name: step_name))
          normalized = ScriptHelper.normalize_script(script_content)

          raise 'Empty script content provided' if normalized.empty?

          script_parts = []
          script_parts << config.header if opts.header && config.header
          script_parts << config.strict_mode if opts.strict && config.strict_mode
          script_parts << config.debug_mode if opts.debug && config.debug_mode
          script_parts.concat(T.must(config.setup_commands)) if opts.setup && config.setup_commands

          script_parts << normalized
          s.run = script_parts.join("\n")
          s.env = opts.env if opts.env

          s
        end
      end
    end
  end
end