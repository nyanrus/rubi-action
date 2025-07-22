# Plugin Development Guide

## Overview

Plugins extend the GitHub Actions DSL with custom builders for steps, jobs, and workflows. They provide domain-specific functionality while maintaining the core DSL's simplicity.

## Plugin Structure

### Basic Plugin Template
```lua
local function create_my_plugin(gha)
  local plugin = gha.plugin()
  
  -- Step builders
  plugin:step_builder("my_step", function(opts)
    local step = gha.step(opts.name or "My Step")
    -- Configure step
    return step
  end)
  
  -- Job builders  
  plugin:job_builder("my_job", function(job, opts)
    -- Configure job
    return job
  end)
  
  -- Workflow builders
  plugin:workflow_builder("my_workflow", function(workflow, opts)
    -- Configure workflow
    return workflow
  end)
  
  return plugin
end

return { create_my_plugin = create_my_plugin }
```

## Step Builders

Step builders create reusable step configurations.

### Simple Step Builder
```lua
plugin:step_builder("docker_build", function(image, tag, opts)
  opts = opts or {}
  local step = gha.step(opts.name or "Build Docker Image")
  
  step:run(string.format("docker build -t %s:%s %s", 
    image, tag, opts.context or "."))
  
  if opts.push then
    step:run(step._run .. " && docker push " .. image .. ":" .. tag)
  end
  
  return step
end)
```

### Advanced Step Builder with Multiple Actions
```lua
plugin:step_builder("test_with_coverage", function(opts)
  opts = opts or {}
  local step = gha.step(opts.name or "Test with Coverage")
  
  -- Multi-line script
  local script = [[
    npm test -- --coverage
    npx codecov
  ]]
  
  step:run(script)
     :env(opts.env or {})
  
  if opts.artifact then
    -- Chain with upload step
    step._run = step._run .. "\n" .. 
      "echo 'coverage-path=./coverage' >> $GITHUB_OUTPUT"
  end
  
  return step
end)
```

## Job Builders

Job builders create preconfigured job templates.

### Service Job Builder
```lua
plugin:job_builder("service_job", function(job, services, opts)
  opts = opts or {}
  
  job:runs_on(opts.runner or "ubuntu-latest")
  
  -- Add services
  job.services = services
  
  -- Standard steps
  job:step("Checkout"):use("actions/checkout@v4")
  
  if opts.setup then
    job:step("Setup"):run(opts.setup)
  end
  
  return job
end)
```

### Matrix Job Builder
```lua
plugin:job_builder("matrix_job", function(job, matrix_config, opts)
  opts = opts or {}
  
  job:runs_on(opts.runner or "ubuntu-latest")
  job.strategy = { matrix = matrix_config }
  
  -- Use matrix variables in steps
  job:step("Setup"):run("echo 'Testing with: ${{ matrix.version }}'")
  
  return job
end)
```

## Workflow Builders

Workflow builders configure entire workflow templates.

### Microservice Workflow Builder
```lua
plugin:workflow_builder("microservice_workflow", function(workflow, services, opts)
  opts = opts or {}
  
  -- Configure common triggers
  workflow:push({ branches = opts.branches or {"main"} })
          :pull_request()
  
  -- Add environment variables
  workflow._env = workflow._env or {}
  workflow._env.REGISTRY = opts.registry or "ghcr.io"
  
  -- Create jobs for each service
  for _, service in ipairs(services) do
    workflow:job(service .. "_test", function(job)
      job:runs_on("ubuntu-latest")
         :step("Checkout"):use("actions/checkout@v4")
         :step("Test " .. service):run("cd " .. service .. " && npm test")
    end)
    
    workflow:job(service .. "_build", function(job)
      job:runs_on("ubuntu-latest")
         :needs({service .. "_test"})
         :step("Checkout"):use("actions/checkout@v4")
         :step("Build " .. service):run("cd " .. service .. " && npm run build")
    end)
  end
  
  return workflow
end)
```

## Language-Specific Helpers

### Script Normalization
```lua
local function normalize_script(script)
  local lines = {}
  for line in script:gmatch("[^\n]*") do
    table.insert(lines, line)
  end
  
  -- Remove empty lines at start/end
  while #lines > 0 and lines[1]:match("^%s*$") do
    table.remove(lines, 1)
  end
  while #lines > 0 and lines[#lines]:match("^%s*$") do
    table.remove(lines, #lines)
  end
  
  if #lines == 0 then return "" end
  
  -- Find minimum indentation
  local min_indent = math.huge
  for _, line in ipairs(lines) do
    if not line:match("^%s*$") then
      local indent = line:match("^(%s*)"):len()
      min_indent = math.min(min_indent, indent)
    end
  end
  
  -- Remove common indentation
  if min_indent > 0 and min_indent < math.huge then
    for i, line in ipairs(lines) do
      if not line:match("^%s*$") then
        lines[i] = line:sub(min_indent + 1)
      end
    end
  end
  
  return table.concat(lines, "\n")
end
```

### Language Builder Template
```lua
local function create_language_builder(lang_config)
  return function(script_content, opts)
    opts = opts or {}
    local step = gha.step(opts.name or ("Run " .. lang_config.name .. " script"))
    
    local normalized = normalize_script(script_content)
    
    -- Add language-specific header
    local full_script = normalized
    if lang_config.header and not normalized:match("^" .. lang_config.header) then
      full_script = lang_config.header .. "\n" .. normalized
    end
    
    step:run(full_script)
    
    -- Set shell if specified
    if lang_config.shell then
      step._shell = lang_config.shell
    end
    
    -- Add environment
    if opts.env then
      step:env(opts.env)
    end
    
    return step
  end
end
```

## Plugin Registration

### Method 1: Direct Registration
```lua
local gha = require('gha/gha_dsl_min')

gha.register_step_builder("custom_step", function(opts)
  -- Implementation
end)
```

### Method 2: Plugin Object
```lua
local plugin = gha.plugin()
  :step_builder("custom_step", function(opts)
    -- Implementation
  end)

gha.load_plugin(plugin)
```

### Method 3: Plugin Factory
```lua
local function create_plugin(gha)
  return gha.plugin()
    :step_builder("custom_step", function(opts)
      -- Implementation
    end)
end

local gha = require('gha/gha_dsl_min')
gha.load_plugin(create_plugin(gha))
```

## Best Practices

### 1. Error Handling
```lua
plugin:step_builder("safe_step", function(opts)
  if not opts or not opts.required_param then
    error("safe_step requires required_param")
  end
  
  local step = gha.step(opts.name or "Safe Step")
  -- Implementation
  return step
end)
```

### 2. Option Validation
```lua
plugin:step_builder("validated_step", function(opts)
  opts = opts or {}
  
  local valid_types = {docker = true, npm = true, maven = true}
  if opts.type and not valid_types[opts.type] then
    error("Invalid type: " .. tostring(opts.type))
  end
  
  -- Implementation
end)
```

### 3. Consistent Naming
- Use snake_case for builder names
- Prefix with domain/tool name
- Use descriptive names: `docker_build`, `npm_test`, `k8s_deploy`

### 4. Documentation
```lua
-- Step builder for Docker operations
-- @param image string - Docker image name
-- @param tag string - Image tag
-- @param opts table - Optional configuration
--   @field context string - Build context path (default: ".")
--   @field push boolean - Push after build (default: false)
--   @field name string - Step name (default: "Build Docker Image")
plugin:step_builder("docker_build", function(image, tag, opts)
  -- Implementation
end)
```

### 5. Chaining Support
Always return the appropriate object to maintain method chaining:
```lua
plugin:job_builder("my_job", function(job, opts)
  -- Configure job
  return job -- Important for chaining
end)
```

## Testing Plugins

### Unit Test Template
```lua
local function test_plugin()
  local gha = require('gha/gha_dsl_min')
  local plugin = create_my_plugin(gha)
  
  -- Test step builder
  local step = plugin:step_builder("test_step", function(opts)
    return gha.step("Test"):run("echo test")
  end)
  
  -- Verify step creation
  local test_step = step({})
  assert(test_step._run == "echo test")
  
  print("Plugin tests passed!")
end
```

## Example: Complete Plugin

See the multi-language helper plugin in the next section for a complete, production-ready example.
