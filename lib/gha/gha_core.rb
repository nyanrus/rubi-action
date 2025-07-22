# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require 'yaml'
require_relative '../helpers/types'

module GHA
  class Core
    extend T::Sig

    sig { params(options: Helpers::StepOptions).returns(Helpers::Step) }
    def self.new_step(options)
      Helpers::Step.new(
        name: options.name,
        run: options.run,
        uses: options.uses,
        with: options.with,
        env: options.env,
        id: options.id,
        if_: options.if_
      )
    end

    sig { params(name: String).returns(Helpers::Job) }
    def self.new_job(name)
      Helpers::Job.new(
        name: name,
        steps: []
      )
    end

    sig { params(name: String).returns(Helpers::Workflow) }
    def self.new_workflow(name)
      Helpers::Workflow.new(
        name: name,
        on: {},
        jobs: {},
        env: {}
      )
    end

    sig { params(job: Helpers::Job, step: Helpers::Step).void }
    def self.add_step(job, step)
      job.steps << step
    end

    sig { params(workflow: Helpers::Workflow, job: Helpers::Job).void }
    def self.add_job(workflow, job)
      workflow.jobs[job.name] = job
    end

    sig { params(workflow: Helpers::Workflow).returns(String) }
    def self.to_yaml(workflow)
      # The custom serializer in types.rb will handle this
      workflow.serialize.to_yaml
    end
  end
end