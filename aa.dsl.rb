# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require 'rubi-action'
require "json"
require_relative 'a'

module PackageWorkflow
  extend T::Sig

  # Constants for better maintainability
  PLATFORMS = JSON.generate({
    'Windows-x64': {
      artifact_name: Messages::WELCOME,
      mozconfig: 'win64.mozconfig',
      output_name: 'win-amd64',
      installer_path: 'install/sea/*installer.exe',
      installer_name: 'noraneko-win64-installer.exe'
    },
    'Linux-x64': {
      artifact_name: 'noraneko-linux-amd64-moz-artifact',
      mozconfig: 'linux64.mozconfig',
      output_name: 'linux-amd64',
      installer_path: 'noraneko*tar.xz',
      installer_name: 'noraneko-linux-amd64.tar.xz'
    },
    'macOS-x64': {
      artifact_name: 'noraneko-mac-universal-moz-artifact-release',
      mozconfig: 'macosx64-x86_64.mozconfig',
      output_name: 'mac-universal',
      installer_path: 'noraneko-*dmg',
      installer_name: 'noraneko-macOS-universal.dmg'
    }
  })

  sig { returns(GHA::Helpers::Workflow) }
  def self.workflow
    api = GHA::API.new_api
    api.load_plugins([GHA::Plugin::LanguagePlugin.create_language_plugin])

    api.workflow '(A) 📦️ Package' do
      on 'workflow_dispatch'
      on 'workflow_call'

      job 'main' do
        runs_on 'ubuntu-latest'

        # Setup steps
        PackageWorkflow.setup_environment(self)
        PackageWorkflow.setup_noraneko(self)
        PackageWorkflow.configure_build(self)

        # Build steps
        PackageWorkflow.download_artifacts(self)
        PackageWorkflow.build_noraneko(self)
        PackageWorkflow.package_and_publish(self)
      end
    end
  end

  private

  # Extract setup steps into a separate method for clarity
  def self.setup_environment(ctx)
    ctx.step 'Checkout runtime', uses: 'actions/checkout@v4', with: {
      'repository' => '${{ github.repository }}-runtime',
      'submodules' => 'recursive'
    }
    ctx.step 'Checkout main', uses: 'actions/checkout@v4', with: {
      'path' => 'noraneko'
    }
    ctx.step 'Setup Node.js', uses: 'actions/setup-node@v4', with: {
      'node-version' => '22'
    }
    ctx.step 'Setup Deno', uses: 'denoland/setup-deno@v2', with: {
      'deno-version' => 'v2.x'
    }
    ctx.step 'Install dependencies', run: 'deno install -g -A npm:zx'
  end

  def self.setup_noraneko(ctx)
    ctx.step 'Setup Noraneko', run: <<~BASH
      cd noraneko && deno install --allow-scripts
    BASH
    ctx.step 'Setup build tools', run: <<~BASH
      sudo apt install msitools -y
      ./mach --no-interactive bootstrap --application-choice browser_artifact_mode
    BASH
    ctx.step 'Write versions', run: 'cd noraneko && deno task build --write-version'
  end

  def self.configure_build(ctx)
    ctx.step 'Configure build', run: build_configuration_script
    ctx.step 'Set environment variables', run: set_environment_variables_script
  end

  def self.download_artifacts(ctx)
    ctx.step 'Download from Actions', uses: 'actions/download-artifact@v4', 
         if_: "${{ env.RUNTIME_ARTIFACT_WORKFLOW_RUN_ID != 'false' }}", 
         with: artifact_download_config

    ctx.step 'Download from Releases', if_: "${{ env.RUNTIME_ARTIFACT_WORKFLOW_RUN_ID == 'false' }}", 
         run: download_from_releases_script

    ctx.step 'Process artifacts (Actions)', if_: "${{ env.RUNTIME_ARTIFACT_WORKFLOW_RUN_ID != 'false' }}", 
         run: process_artifacts_actions_script

    ctx.step 'Process artifacts (Releases)', if_: "${{ env.RUNTIME_ARTIFACT_WORKFLOW_RUN_ID == 'false' }}", 
         run: process_artifacts_releases_script
  end

  def self.build_noraneko(ctx)
    ctx.step 'Pre-build Noraneko', run: 'cd noraneko && NODE_ENV=production deno task build --release-build-before'
    ctx.step 'Build with Mozilla artifacts', run: build_with_artifacts_script
    ctx.step 'Inject Noraneko', run: inject_noraneko_script
    ctx.step 'Package', run: './mach package'
    ctx.step 'Prepare installer', run: prepare_installer_script
  end

  def self.package_and_publish(ctx)
    PackageWorkflow.download_mar_tools(ctx)
    ctx.step 'Create MAR package', run: create_mar_package_script
    ctx.step 'Publish installer', uses: 'actions/upload-artifact@v4', with: {
      'name' => 'noraneko-${{ env.OUTPUT_NAME }}-installer',
      'path' => '~/noraneko-installer/*',
      'compression-level' => '9'
    }
    ctx.step 'Publish MAR', uses: 'actions/upload-artifact@v4', with: {
      'name' => 'noraneko-${{ env.OUTPUT_NAME }}-mar-full',
      'path' => '~/noraneko-publish/*'
    }
  end

  def self.download_mar_tools(ctx)
    ctx.step 'Download MAR tools (Actions)', uses: 'actions/download-artifact@v4',
         if_: "${{ env.RUNTIME_ARTIFACT_WORKFLOW_RUN_ID != 'false' }}",
         with: mar_tools_actions_config

    ctx.step 'Download MAR tools (Releases)', if_: "${{ env.RUNTIME_ARTIFACT_WORKFLOW_RUN_ID == 'false' }}",
         run: download_mar_tools_releases_script

    ctx.step 'Download build info (Actions)', uses: 'actions/download-artifact@v4',
         if_: "${{ env.RUNTIME_ARTIFACT_WORKFLOW_RUN_ID != 'false' }}",
         with: build_info_actions_config

    ctx.step 'Download build info (Releases)', if_: "${{ env.RUNTIME_ARTIFACT_WORKFLOW_RUN_ID == 'false' }}",
         run: download_build_info_releases_script
  end

  # Script generators
  def self.build_configuration_script
    <<~BASH
      # Select mozconfig based on platform
      case "${{inputs.platform}}" in
        "Windows-x64") cp ./.github/workflows/mozconfigs/win64.mozconfig mozconfig ;;
        "Linux-x64") cp ./.github/workflows/mozconfigs/linux64.mozconfig mozconfig ;;
        *) cp ./.github/workflows/mozconfigs/macosx64-x86_64.mozconfig mozconfig ;;
      esac

      # Setup branding and versioning
      cp -r ./noraneko/gecko/branding/* ./browser/branding/
      mkdir -p noraneko/gecko/config/autogenerated
      
      # Create version files
      echo "$(cat browser/config/version.txt)@$(cat noraneko/gecko/config/version.txt)" > noraneko/gecko/config/autogenerated/version.txt
      echo "$(cat browser/config/version_display.txt)@$(cat noraneko/gecko/config/version_display.txt)" > noraneko/gecko/config/autogenerated/version_display.txt
      
      # Configure build options
      cat >> mozconfig << 'EOF'
      ac_add_options --with-version-file-path=noraneko/gecko/config/autogenerated
      ac_add_options --enable-release
      ac_add_options --enable-update-channel=alpha
      ac_add_options --disable-tests
      ac_add_options --enable-artifact-builds
      mk_add_options MOZ_OBJDIR=./obj-artifact-build-output
      EOF

      # Platform-specific configuration
      sed -i 's|ac_add_options --disable-updater||g' ./mozconfig
      sed -i 's|ac_add_options --enable-unverified-updates||g' ./mozconfig
      sed -i 's|MOZ_BRANDING_DIRECTORY=browser/branding/unofficial|MOZ_BRANDING_DIRECTORY=browser/branding/noraneko-unofficial|g' ./browser/confvars.sh
      sed -i 's|ac_add_options --enable-chrome-format=flat||g' ./mozconfig

      # macOS-specific setup
      if [ "${{inputs.platform}}" == "macOS-x64" ]; then
        setup_macos_tools
      fi

      ./mach configure
      git apply --ignore-space-change --ignore-whitespace .github/patches/packaging/*.patch
    BASH
  end

  def self.set_environment_variables_script
    <<~JAVASCRIPT % [PLATFORMS]
      // Set runtime artifact workflow run ID
      if (!process.env.INPUT_RUNTIME_ARTIFACT_WORKFLOW_RUN_ID) {
        await $`echo "RUNTIME_ARTIFACT_WORKFLOW_RUN_ID=false" >> $GITHUB_ENV`;
      } else {
        await $`echo "RUNTIME_ARTIFACT_WORKFLOW_RUN_ID=${process.env.INPUT_RUNTIME_ARTIFACT_WORKFLOW_RUN_ID}" >> $GITHUB_ENV`;
      }

      // Platform-specific environment variables
      const platformConfig = JSON.parse(`%s`);

      const config = platformConfig[process.env.BUILD_PLATFORM];
      if (config) {
        for (const [key, value] of Object.entries(config)) {
          const envKey = key.replace(/([A-Z])/g, '_$1').toUpperCase();
          await $`echo "${envKey}=${value}" >> $GITHUB_ENV`;
        }
      }
    JAVASCRIPT
  end

  def self.create_mar_package_script
    <<~'RUBY'
      require 'fileutils'
      require 'json'
      require 'digest'

      class MarPackageBuilder
        def initialize
          @obj_dir = find_obj_dir
          @paths = setup_paths
          setup_directories
        end

        def build
          setup_mar_tool
          extract_build_info
          create_mar_file
          generate_metadata
          copy_to_publish_dir
        end

        private

        def find_obj_dir
          Dir.glob('./obj-*').first or raise 'Could not find obj-* directory'
        end

        def setup_paths
          home_dir = Dir.home
          {
            mar_dir: File.join(home_dir, 'noraneko-mar'),
            publish_dir: File.join(home_dir, 'noraneko-publish'),
            dev_dir: File.join(home_dir, 'noraneko-dev'),
            application_ini: File.join(home_dir, 'noraneko-dev', 'nora-application.ini'),
            mar_tool: File.join(@obj_dir, 'dist', 'host', 'bin', 'mar')
          }
        end

        def setup_directories
          [@paths[:mar_dir], @paths[:publish_dir]].each { |dir| FileUtils.mkdir_p(dir) }
        end

        def setup_mar_tool
          FileUtils.chmod('+x', @paths[:mar_tool])
        end

        def extract_build_info
          content = File.read(@paths[:application_ini])
          @version = content[/^Version=(.*)$/, 1]&.strip or raise 'Could not extract Version'
          @build_id = content[/^BuildID=(.*)$/, 1]&.strip or raise 'Could not extract BuildID'
        end

        def create_mar_file
          @mar_file_name = "noraneko-#{ENV['OUTPUT_NAME'] || 'unknown'}-full.mar"
          @mar_file_path = File.join(@paths[:mar_dir], @mar_file_name)
          # Create precomplete file
          FileUtils.touch(File.join(@obj_dir, 'dist', 'noraneko', 'precomplete'))
          # Build MAR package
          env = {
            'MAR' => @paths[:mar_tool],
            'MOZ_PRODUCT_VERSION' => @version,
            'MAR_CHANNEL_ID' => 'alpha'
          }
          system(env, "./tools/update-packaging/make_full_update.sh \"#{@mar_file_path}\" \"#{File.join(@obj_dir, 'dist', 'noraneko')}\"")
        end

        def generate_metadata
          noraneko_version = File.read('noraneko/gecko/config/version.txt').strip
          noraneko_buildid = File.read('noraneko/_dist/buildid2').strip
          metadata = {
            version: @version,
            noraneko_version: noraneko_version,
            noraneko_buildid: noraneko_buildid,
            mar_size: File.size(@mar_file_path).to_s,
            mar_shasum: Digest::SHA512.file(@mar_file_path).hexdigest,
            buildid: @build_id
          }
          File.write(File.join(@paths[:publish_dir], 'meta.json'), JSON.pretty_generate(metadata))
        end

        def copy_to_publish_dir
          FileUtils.cp(@mar_file_path, @paths[:publish_dir])
        end
      end

      MarPackageBuilder.new.build
    RUBY
  end

  # Additional helper methods for other scripts...
  def self.build_with_artifacts_script
    <<~BASH
      # Backup for rollback capability
      cp -r obj-artifact-build-output obj-artifact-build-output.bak

      case "${{inputs.platform}}" in
        "Windows-x64")
          MOZ_ARTIFACT_FILE=~/artifacts/noraneko-win-amd64-moz-artifact.zip ./mach build
          ;;
        "Linux-x64")
          MOZ_ARTIFACT_FILE=~/artifacts/noraneko-linux-amd64-moz-artifact.tar.xz ./mach build
          ;;
        "macOS-x64")
          MOZ_ARTIFACT_FILE=~/artifacts/noraneko-macOS-universal-moz-artifact.dmg:~/artifacts/noraneko-macOS.update_framework_artifacts.zip ./mach build
          ;;
      esac
    BASH
  end

  def self.inject_noraneko_script
    <<~BASH
      # Backup for rollback
      cp -r obj-artifact-build-output/dist/bin obj-artifact-build-output/dist/bin.bak

      cd noraneko
      deno task build --release-build-after
      
      # Sync and replace bin directory
      rsync -aL ../obj-artifact-build-output/dist/bin/ ../obj-artifact-build-output/dist/tmp__bin
      rm -rf ../obj-artifact-build-output/dist/bin
      mv ../obj-artifact-build-output/dist/tmp__bin ../obj-artifact-build-output/dist/bin

      # Apply patches based on platform
      if [ "${{inputs.platform}}" == "macOS-x64" ]; then
        apply_macos_patches
      else
        git apply --reject ./scripts/git-patches/patches/*.patch \
          --directory ../obj-artifact-build-output/dist/bin \
          --unsafe-paths --check --apply
      fi

      cd ..
    BASH
  end

  # Configuration helpers
  def self.artifact_download_config
    {
      'name' => '${{ env.ARTIFACT_NAME }}',
      'run-id' => '${{ env.RUNTIME_ARTIFACT_WORKFLOW_RUN_ID }}',
      'github-token' => '${{ github.token }}',
      'repository' => '${{ github.repository }}-runtime',
      'path' => '~/downloads'
    }
  end

  def self.mar_tools_actions_config
    {
      'pattern' => '*dist-host',
      'run-id' => '${{ env.RUNTIME_ARTIFACT_WORKFLOW_RUN_ID }}',
      'github-token' => '${{ github.token }}',
      'repository' => '${{ github.repository }}-runtime',
      'path' => 'obj-artifact-build-output/dist/host',
      'merge-multiple' => 'true'
    }
  end

  def self.build_info_actions_config
    {
      'pattern' => '*application-ini',
      'run-id' => '${{ env.RUNTIME_ARTIFACT_WORKFLOW_RUN_ID }}',
      'github-token' => '${{ github.token }}',
      'repository' => '${{ github.repository }}-runtime',
      'path' => '~/noraneko-dev',
      'merge-multiple' => 'true'
    }
  end

  # Additional script methods would go here...
  def self.download_from_releases_script
    <<~BASH
      mkdir -p ~/downloads
      curl -L "https://github.com/${{ github.repository }}-runtime/releases/latest/download/${{ env.ARTIFACT_FROM_RELEASE_NAME }}" \
        -o "~/downloads/${{ env.ARTIFACT_FROM_RELEASE_NAME }}"
    BASH
  end

  def self.process_artifacts_actions_script
    <<~BASH
      mkdir -p ~/artifacts
      cd ~/downloads
      if [ "${{inputs.platform}}" == "Windows-x64" ]; then
        zip -r ~/artifacts/noraneko-win-amd64-moz-artifact.zip ./*
      else
        cp -r ~/downloads/* ~/artifacts
      fi
      cd "$GITHUB_WORKSPACE"
    BASH
  end

  def self.process_artifacts_releases_script
    <<~BASH
      mkdir -p ~/artifacts
      cd ~/downloads
      if [ "${{inputs.platform}}" == "macOS-x64" ]; then
        unzip noraneko-mac-universal-moz-artifact-release.zip -d ~/artifacts
      else
        cp -r ~/downloads/* ~/artifacts
      fi
      cd "$GITHUB_WORKSPACE"
    BASH
  end

  def self.prepare_installer_script
    <<~BASH
      mkdir -p ~/noraneko-installer
      mv obj-*/dist/$INSTALLER_PATH ~/noraneko-installer/$OUTPUT_INSTALLER_NAME
    BASH
  end

  def self.download_mar_tools_releases_script
    <<~BASH
      curl -L "https://github.com/${{ github.repository }}-runtime/releases/latest/download/${{ inputs.platform }}-dist-host.zip" \
        -o "~/downloads/${{ inputs.platform }}-dist-host.zip"
      unzip "~/downloads/${{ inputs.platform }}-dist-host.zip" -d ./obj-artifact-build-output/dist/host
    BASH
  end

  def self.download_build_info_releases_script
    <<~BASH
      curl -L "https://github.com/${{ github.repository }}-runtime/releases/latest/download/${{ inputs.platform }}-application-ini.zip" \
        -o "~/downloads/${{ inputs.platform }}-application-ini.zip"
      unzip "~/downloads/${{ inputs.platform }}-application-ini.zip" -d ~/noraneko-dev
    BASH
  end
end