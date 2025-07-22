# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module GHA
  module Helpers
    # Defines the options for a single step in a GitHub Actions workflow.
    # This includes properties like the command to run, environment variables, and conditions.
    class StepOptions < T::Struct
      extend T::Sig
      const :name, T.nilable(String)
      const :run, T.nilable(String)
      const :uses, T.nilable(String)
      const :with, T.nilable(T::Hash[String, String])
      const :env, T.nilable(T::Hash[String, String])
      const :id, T.nilable(String)
      const :if_, T.nilable(String)
      const :shell, T.nilable(String)

      sig { params(strict: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = nil)
        super(strict: strict).compact
      end
    end

    # Defines the conditions that trigger a GitHub Actions workflow, such as pushes to specific branches or tags.
    class WorkflowTrigger < T::Struct
      extend T::Sig
      const :branches, T.nilable(T::Array[String])
      const :tags, T.nilable(T::Array[String])
      const :paths, T.nilable(T::Array[String])

      sig { params(strict: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = nil)
        super(strict: strict).compact
      end
    end

    # Represents a single step (a command or action) within a job in a GitHub Actions workflow.
    class Step < T::Struct
      extend T::Sig
      const :name, T.nilable(String)
      prop :run, T.nilable(String)
      prop :uses, T.nilable(String)
      prop :with, T.nilable(T::Hash[String, String])
      prop :env, T.nilable(T::Hash[String, String])
      prop :id, T.nilable(String)
      prop :if_, T.nilable(String)

      sig { params(strict: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = nil)
        super(strict: strict).compact
      end
    end

    # Represents a single job within a GitHub Actions workflow.
    # A job is a set of steps that execute on the same runner.
    class Job < T::Struct
      extend T::Sig
      const :name, String
      prop :runs_on, T.nilable(String)
      prop :needs, T.nilable(T::Array[String])
      prop :env, T.nilable(T::Hash[String, String])
      const :steps, T::Array[Step], default: []
      prop :strategy, T.nilable(String)

      sig { params(strict: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = nil)
        h = super(strict: strict)
        h[:steps] = h[:steps]&.map(&:serialize)
        h.compact
      end
    end

    # Represents a complete GitHub Actions workflow, including its name, triggers, and jobs.
    class Workflow < T::Struct
      extend T::Sig
      const :name, String
      prop :on, T::Hash[String, WorkflowTrigger], default: {}
      prop :jobs, T::Hash[String, Job], default: {}
      prop :env, T.nilable(T::Hash[String, String])

      sig { params(strict: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = nil)
        h = super(strict: strict)
        h[:on] = h[:on]&.transform_values(&:serialize)
        h[:jobs] = h[:jobs]&.transform_values(&:serialize)
        h.compact
      end
    end

    # Holds metadata about a method provided by a GHA plugin, including its description, parameters, and return values.
    class PluginMethodInfo < T::Struct
      const :name, String
      const :description, String
      const :params, T.nilable(T::Hash[String, String])
      const :returns, T.nilable(String)
      const :example, T.nilable(String)
    end

    # Defines the structure for a GHA plugin, including its metadata and the builders it provides for steps, jobs, and workflows.
    class GHAPlugin < T::Struct
      const :name, String
      const :version, String
      const :description, String
      const :step_methods, T::Hash[String, PluginMethodInfo]
      const :job_methods, T::Hash[String, PluginMethodInfo]
      const :workflow_methods, T::Hash[String, PluginMethodInfo]
      const :step_builders, T::Hash[String, T.proc.params(script: String, opts: T::Hash[String, String]).returns(Step)]
      const :job_builders, T.nilable(T::Hash[String, T.proc.params(name: String, opts: T::Hash[String, String]).returns(Job)])
      const :workflow_builders, T.nilable(T::Hash[String, T.proc.params(name: String, opts: T::Hash[String, String]).returns(Workflow)])
    end

    # Manages all registered plugins and their associated builders for steps, jobs, and workflows.
    class PluginRegistry < T::Struct
      const :step_builders, T::Hash[String, T.proc.params(script: String, opts: T::Hash[String, String]).returns(Step)]
      const :job_builders, T::Hash[String, T.proc.params(name: String, opts: T::Hash[String, String]).returns(Job)]
      const :workflow_builders, T::Hash[String, T.proc.params(name: String, opts: T::Hash[String, String]).returns(Workflow)]
      const :loaded_plugins, T::Hash[String, GHAPlugin]
    end

    # Holds language-specific configuration for generating workflow files, such as headers, strict modes, and setup commands.
    class LanguageConfig < T::Struct
      const :name, String
      const :header, T.nilable(String)
      const :strict_mode, T.nilable(String)
      const :debug_mode, T.nilable(String)
      const :setup_commands, T.nilable(T::Array[String])
      const :shell, T.nilable(String)
    end

    # Defines a set of common options used by various builders to customize the generated workflow components.
    class BuilderOptions < T::Struct
      const :name, T.nilable(String)
      const :step, T.nilable(Step)
      const :header, T.nilable(T::Boolean)
      const :strict, T.nilable(T::Boolean)
      const :debug, T.nilable(T::Boolean)
      const :setup, T.nilable(T::Boolean)
      const :env, T.nilable(T::Hash[String, String])
      const :lang, T.nilable(String)
    end
  end
end