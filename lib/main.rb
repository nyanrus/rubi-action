# lib/main.rb
require 'fileutils'
require 'yaml'

# Load your GHA modules
require_relative '../gha/gha_plugin'  # Adjust path as needed

module RubiAction
  module DSL
    class TransformationError < StandardError; end
    
    def self.transform(ruby_code)
      begin
        # Create a proper execution context
        context = ExecutionContext.new
        
        # Execute the Ruby code in the proper context
        workflow = context.instance_eval(ruby_code)
        
        # Handle different return types
        case workflow
        when GHA::Helpers::Workflow
          # If it returns a workflow object directly
          workflow.to_yaml
        when Module
          # If it returns a module (like PackageWorkflow), call the workflow method
          if workflow.respond_to?(:workflow)
            workflow.workflow.to_yaml
          else
            raise TransformationError, "Module #{workflow} doesn't have a workflow method"
          end
        else
          raise TransformationError, "Expected workflow object or module, got #{workflow.class}"
        end
        
      rescue NameError => e
        if e.message.include?("cannot infer basepath")
          handle_basepath_error(e, ruby_code)
        else
          "# 변환 실패: #{e.message}\n# 스택 트레이스:\n# #{e.backtrace.join("\n# ")}"
        end
      rescue Exception => e
        "# 변환 실패: #{e.message}\n# 스택 트레이스:\n# #{e.backtrace.join("\n# ")}"
      end
    end
    
    private
    
    def self.handle_basepath_error(error, ruby_code)
      # Provide more specific error handling for basepath issues
      suggestion = if ruby_code.include?('require_relative')
        "파일 경로를 확인하세요. require_relative 경로가 올바른지 검사하세요."
      elsif ruby_code.include?('GHA::')
        "GHA 모듈이 제대로 로드되었는지 확인하세요."
      else
        "DSL 파일의 구조를 확인하세요."
      end
      
      "# 변환 실패: cannot infer basepath\n# 제안: #{suggestion}\n# 원본 오류: #{error.message}"
    end
    
    # Execution context that provides the DSL environment
    class ExecutionContext
      def initialize
        # Load necessary modules and create API instance
        setup_dsl_environment
      end
      
      private
      
      def setup_dsl_environment
        # Ensure GHA modules are available
        unless defined?(GHA::API)
          raise TransformationError, "GHA::API is not defined. Please check your GHA module loading."
        end
        
        # Set up any necessary base paths or configurations
        @base_path = File.dirname(caller_locations.first.path)
      end
      
      # Provide require_relative in the context if needed
      def require_relative(path)
        require File.join(@base_path, path)
      end
    end
  end
end

# Alternative approach: Direct module execution
module RubiAction
  module DSL
    def self.transform_module(ruby_code, module_name = nil)
      begin
        # Load the Ruby file and get the module
        Object.class_eval(ruby_code)
        
        # Try to find the workflow module
        workflow_module = if module_name
          Object.const_get(module_name)
        else
          # Auto-detect workflow modules
          find_workflow_module
        end
        
        unless workflow_module&.respond_to?(:workflow)
          raise TransformationError, "No workflow method found in module"
        end
        
        # Generate the workflow and convert to YAML
        workflow_obj = workflow_module.workflow
        workflow_obj.to_yaml
        
      rescue Exception => e
        "# 변환 실패 (모듈 방식): #{e.message}\n"
      end
    end
    
    private
    
    def self.find_workflow_module
      # Look for modules that have a workflow method
      ObjectSpace.each_object(Module).find do |mod|
        mod.respond_to?(:workflow) && mod.name&.include?('Workflow')
      end
    end
  end
end

# Enhanced transform_dir function
def transform_dir(input_dir, output_dir)
  unless Dir.exist?(input_dir)
    warn "[ERROR] 입력 디렉토리 #{input_dir}이(가) 존재하지 않습니다."
    exit 1
  end
  
  Dir.glob(File.join(input_dir, "**/*.rb")).each do |file|
    begin
      puts "[INFO] 변환 중: #{file}"
      ruby_code = File.read(file)
      
      # Try the main transform method first
      yaml = RubiAction::DSL.transform(ruby_code)
      
      # If that fails, try the module-based approach
      if yaml.start_with?("# 변환 실패")
        puts "[WARN] 기본 변환 실패, 모듈 방식으로 재시도..."
        yaml = RubiAction::DSL.transform_module(ruby_code)
      end
      
      rel = file.sub(/^#{Regexp.escape(input_dir)}\/?/, '').sub(/\.rb$/, '.yml')
      out_path = File.join(output_dir, rel)
      
      FileUtils.mkdir_p(File.dirname(out_path))
      File.write(out_path, yaml)
      
      if yaml.start_with?("# 변환 실패")
        puts "[ERROR] #{file} -> #{out_path} (실패)"
      else
        puts "[SUCCESS] #{file} -> #{out_path}"
      end
      
    rescue Exception => e
      puts "[ERROR] #{file} 변환 중 오류: #{e.message}"
    end
  end
end

if __FILE__ == $0
  input_dir = ARGV[0] || 'dsl'
  output_dir = ARGV[1] || '.github/workflows'
  transform_dir(input_dir, output_dir)
end