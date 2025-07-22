# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative '../gha/gha_plugin'
require_relative '../helpers/types'

module GHA
  class Plugin
    module LanguagePlugin
      extend T::Sig

      sig { returns(GHA::Helpers::GHAPlugin) }
      def self.create_language_plugin
        plugin = GHA::Plugin.new_plugin(name: 'languages', version: '0.1.0', description: 'Provides language-specific script builders')
        # step_builderの登録は行わない（JobBuilderの明示的なメソッドのみを使う）
        plugin
      end
    end
  end
end