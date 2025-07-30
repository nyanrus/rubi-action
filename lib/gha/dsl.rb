# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative '../helpers/types'
require_relative 'gha_core'
require_relative '../helpers/script_helper'
require_relative '../helpers/result'
require 'stringio'

module GHA
  class JobBuilder
    extend T::Sig
    extend T::Helpers

    # Initializes a new JobBuilder.
    # @param api [API] The API instance.
    # @param job [Helpers::Job] The job to build.
    # @return [void]
    sig { params(api: API, job: Helpers::Job).void }
    def initialize(api, job)
      @api = api
      @job = job
    end

    # Sets the runner for the job.
    #
    # @param runner [String] The name of the runner (e.g., "ubuntu-latest").
    # @return [void]
    sig { params(runner: String).void }
    def runs_on(runner)
      @job.runs_on = runner
    end

    # Adds a step to the job.
    #
    # @param name [String] The name of the step.
    # @param uses [String, nil] The action to use (e.g., "actions/checkout@v2").
    # @param with [Hash<String, String>, nil] A hash of inputs for the action.
    # @param run [String, nil] The command to run.
    # @param shell [String, nil] The shell to use for the step.
    # @param env [Hash<String, String>, nil] Environment variables for the step.
    # @param if_ [String, nil] Condition for the step.
    # @return [void]
    sig { params(name: String, uses: T.nilable(String), with: T.nilable(T::Hash[String, String]), run: T.nilable(String), shell: T.nilable(String), env: T.nilable(T::Hash[String, String]), if_: T.nilable(String)).void }
    def step(name, uses: nil, with: nil, run: nil, shell: nil, env: nil, if_: nil)
      options = Helpers::StepOptions.new(name: name, uses: uses, with: with, run: run, shell: shell, env: env, if_: if_)
      new_step = GHA::Core.new_step(options)
      GHA::Core.add_step(@job, new_step)
    end

    private

    # Helper to capture script from block
    sig { params(block: T.proc.void).returns(String) }
    def capture_script(&block)
      old_stdout = $stdout
      $stdout = StringIO.new
      begin
        block.call
        $stdout.string
      ensure
        $stdout = old_stdout
      end
    end
  end

  class WorkflowBuilder
    extend T::Sig
    extend T::Helpers

    # Initializes a new WorkflowBuilder.
    # @param api [API] The API instance.
    # @param workflow [Helpers::Workflow] The workflow to build.
    # @return [void]
    sig { params(api: API, workflow: Helpers::Workflow).void }
    def initialize(api, workflow)
      @api = api
      @workflow = workflow
    end

    # Configures the workflow trigger.
    #
    # @param event [String] The name of the event (e.g., "push").
    # @param config [Hash] A hash of trigger configurations (e.g., { branches: ["main"] }).
    # @return [void]
    sig { params(event: String, config: T.untyped).void }
    def on(event, config = {})
      @workflow.on[event] = GHA::Helpers::WorkflowTrigger.new(**T.unsafe(config))
    end

    # Defines a job in the workflow.
    #
    # @param name [String] The name of the job.
    # @yield [GHA::JobBuilder] A block to configure the job.
    # @return [void]
    sig { params(name: String, block: T.proc.bind(JobBuilder).void).void }
    def job(name, &block)
      new_job = @api.job(name)
      job_builder = JobBuilder.new(@api, new_job)

      @api.registry.step_builders.each do |builder_name, builder_proc|
        job_builder.define_singleton_method(builder_name) do |*args, **opts, &block|
          script = args.first
          step_opts = opts

          script_content = if block_given? && block
            old_stdout = $stdout
            $stdout = StringIO.new
            begin
              T.unsafe(block).call
              $stdout.string
            ensure
              $stdout = old_stdout
            end
          elsif script
            script
          else
            nil
          end

          raise ArgumentError, "Missing script content for #{builder_name} step" if script_content.nil? || script_content.empty?

          step = builder_proc.call(script_content, step_opts)
          GHA::Core.add_step(new_job, step)
        end
      end

      job_builder.instance_eval(&block)
      GHA::Core.add_job(@workflow, new_job)
    end
  end
end