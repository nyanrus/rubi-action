# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'result'

module GHA
  module Helpers
    module ScriptHelper
      extend T::Sig

      sig { params(path: String).returns(T.any(Result::Success[String], Result::Failure[String])) }
      def self.read_script(path)
        begin
          content = File.read(path)
          Result::Success.new(content)
        rescue Errno::ENOENT
          Result::Failure.new("File not found at path: #{path}")
        end
      end

      sig { params(script: String).returns(String) }
      def self.normalize_script(script)
        lines = script.split("\n")
        lines.shift while lines.first&.strip&.empty?
        lines.pop while lines.last&.strip&.empty?
        return '' if lines.empty?

        min_indent = lines.filter { |line| !line.strip.empty? }.map { |line| line.index(/S/) || 0 }.min || 0
        return lines.join("\n") if min_indent == 0

        lines.map { |line| line.strip.empty? ? '' : line[min_indent..] }.join("\n")
      end
    end
  end
end