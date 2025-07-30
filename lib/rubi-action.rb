
# rubi-action: package entrypoint
require_relative 'rubi-action/gha/gha_core'
require_relative 'rubi-action/gha/gha_plugin'
require_relative 'rubi-action/gha/dsl'
require_relative 'rubi-action/helpers/types'
require_relative 'rubi-action/helpers/step_factory'
require_relative 'rubi-action/helpers/script_helper'
require_relative 'rubi-action/helpers/result'
require_relative 'rubi-action/plugin/language_plugin'

# for LSP: ensure GHA namespace is always defined
module GHA; end
