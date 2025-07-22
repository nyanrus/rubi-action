# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative '../helpers/types'
require_relative 'gha_core'
require_relative 'dsl'

module GHA
  class Plugin
    extend T::Sig

    sig do
      params(
        name: String,
        version: String,
        description: String
      ).returns(Helpers::GHAPlugin)
    end
    def self.new_plugin(name:, version: '', description: '')
      Helpers::GHAPlugin.new(
        name: name,
        version: version,
        description: description,
        step_methods: {},
        job_methods: {},
        workflow_methods: {},
        step_builders: {},
        job_builders: {},
        workflow_builders: {}
      )
    end

    sig do
      params(
        plugin: Helpers::GHAPlugin,
        name: String,
        builder: T.proc.params(script: String, opts: T.untyped).returns(Helpers::Step),
        info: Helpers::PluginMethodInfo
      ).void
    end
    def self.add_step_builder(plugin, name, builder, info)
      plugin.step_builders[name] = builder
      plugin.step_methods[name] = info
    end
  end

  class PluginRegistry
    extend T::Sig

    sig { returns(Helpers::PluginRegistry) }
    def self.new_registry
      Helpers::PluginRegistry.new(
        step_builders: {},
        job_builders: {},
        workflow_builders: {},
        loaded_plugins: {}
      )
    end

    sig { params(registry: Helpers::PluginRegistry, plugin: Helpers::GHAPlugin).void }
    def self.load_plugin(registry, plugin)
      registry.loaded_plugins[plugin.name] = plugin
      plugin.step_builders.each do |name, builder|
        registry.step_builders[name] = builder
      end
      plugin.job_builders&.each do |name, builder|
        registry.job_builders[name] = builder
      end
      plugin.workflow_builders&.each do |name, builder|
        registry.workflow_builders[name] = builder
      end
    end

    sig { params(registry: Helpers::PluginRegistry, plugins: T::Array[Helpers::GHAPlugin]).void }
    def self.load_plugins(registry, plugins)
      plugins.each { |plugin| load_plugin(registry, plugin) }
    end
  end

  class API
    extend T::Sig

    sig { returns(T.attached_class) }
    def self.new_api
      new(registry: PluginRegistry.new_registry)
    end

    sig { returns(Helpers::PluginRegistry) }
    attr_reader :registry

    sig { params(registry: Helpers::PluginRegistry).void }
    def initialize(registry:)
      @registry = registry
    end

    # Creates a new workflow.
    #
    # @param name [String] The name of the workflow.
    # @yield [GHA::WorkflowBuilder] A block to configure the workflow.
    # @return [GHA::Helpers::Workflow] The configured workflow.
    sig do
      params(
        name: String,
        block: T.nilable(T.proc.bind(WorkflowBuilder).void)
      ).returns(Helpers::Workflow)
    end
    def workflow(name, &block)
      new_workflow = Core.new_workflow(name)
      if block
        builder = WorkflowBuilder.new(self, new_workflow)
        builder.instance_eval(&block)
      end
      new_workflow
    end

    sig { params(name: String).returns(Helpers::Job) }
    def job(name)
      Core.new_job(name)
    end

    sig { params(options: Helpers::StepOptions).returns(Helpers::Step) }
    def step(options)
      Core.new_step(options)
    end

    # Loads a list of plugins into the API registry.
    #
    # @param plugins [Array<GHA::Helpers::GHAPlugin>] The plugins to load.
    # @return [void]
    sig { params(plugins: T::Array[Helpers::GHAPlugin]).void }
    def load_plugins(plugins)
      PluginRegistry.load_plugins(@registry, plugins)
    end
  end
end