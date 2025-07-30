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

    sig { params(api: API, job: Helpers::Job).void }
    def initialize(api, job)
      @api = api
      @job = job
    end

    sig { params(runner: String).void }
    def runs_on(runner)
      @job.runs_on = runner
    end

    sig { params(name: String, uses: T.nilable(String), with: T.nilable(T::Hash[String, String]), run: T.nilable(String), shell: T.nilable(String), env: T.nilable(T::Hash[String, String]), if_: T.nilable(String), block: T.nilable(T.proc.void)).void }
    def step(name, uses: nil, with: nil, run: nil, shell: nil, env: nil, if_: nil, &block)
      script = run
      if block_given?
        old_stdout = $stdout
        $stdout = StringIO.new
        begin
          block.call
          script = $stdout.string
        ensure
          $stdout = old_stdout
        end
      end
      options = Helpers::StepOptions.new(name: name, uses: uses, with: with, run: script, shell: shell, env: env, if_: if_)
      step = GHA::Core.new_step(options)
      GHA::Core.add_step(@job, step)
    end
  end

  class WorkflowBuilder
    extend T::Sig

    sig { params(api: API, workflow: Helpers::Workflow).void }
    def initialize(api, workflow)
      @api = api
      @workflow = workflow
    end

    sig { params(event: String, config: T.untyped).void }
    def on(event, config = {})
      @workflow.on[event] = GHA::Helpers::WorkflowTrigger.new(**T.unsafe(config))
    end

    sig { params(name: String, block: T.proc.bind(JobBuilder).void).void }
    def job(name, &block)
      new_job = @api.job(name)
      job_builder = JobBuilder.new(@api, new_job)
      # プラグインのstep_builderをJobBuilderに動的追加
      @api.registry.step_builders.each do |builder_name, builder_proc|
        job_builder.define_singleton_method(builder_name) do |script = nil, **opts, &blk|
          content = script
          if blk
            old_stdout = $stdout
            $stdout = StringIO.new
            begin
              blk.call
              content = $stdout.string
            ensure
              $stdout = old_stdout
            end
          end
          raise ArgumentError, "Missing script content for #{builder_name} step" if content.nil? || content.empty?
          step = builder_proc.call(content, opts)
          GHA::Core.add_step(new_job, step)
        end
      end
      job_builder.instance_eval(&block)
      GHA::Core.add_job(@workflow, new_job)
    end
  end
end