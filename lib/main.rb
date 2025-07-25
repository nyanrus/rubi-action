
# rubi-action DSL 변환 실행 진입점
require 'fileutils'

module RubiAction
  module DSL
    # ruby_code: String -> YAML String 반환
    def self.transform(ruby_code)
      # 실제 DSL 파싱 및 YAML 변환 구현 필요
      # 예시: GHA::Core.to_yaml(eval(ruby_code))
      begin
        workflow = eval(ruby_code)
        if defined?(GHA::Core)
          GHA::Core.to_yaml(workflow)
        else
          "# 변환 실패: GHA::Core 미정의\n"
        end
      rescue Exception => e
        "# 변환 실패: #{e.message}\n"
      end
    end
  end
end

def transform_dir(input_dir, output_dir)
  Dir.glob(File.join(input_dir, "**/*.rb")).each do |file|
    ruby_code = File.read(file)
    yaml = RubiAction::DSL.transform(ruby_code)
    rel = file.sub(/^#{Regexp.escape(input_dir)}\/?/, '').sub(/\.rb$/, '.yml')
    out_path = File.join(output_dir, rel)
    FileUtils.mkdir_p(File.dirname(out_path))
    File.write(out_path, yaml)
    puts "[INFO] #{file} -> #{out_path}"
  end
end

if __FILE__ == $0
  input_dir = ARGV[0] || 'dsl'
  output_dir = ARGV[1] || '.github/workflows'
  transform_dir(input_dir, output_dir)
end