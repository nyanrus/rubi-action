# ruby-action

GitHub Actions 워크플로우를 Ruby DSL로 작성하고, YAML로 변환하여 자동화할 수 있는 Ruby Gem 및 GitHub Action입니다.

## 설치 및 사용법

### 1. Gem 설치

Gemfile에 추가:

```ruby
gem 'ruby-action', git: 'https://github.com/nyanrus/rubi-action.git'
```

### 2. Ruby DSL 예제

`dsl/workflow.rb`:

```ruby
require 'ruby-action'
# ...DSL 코드 작성 (example.rb 참고)...
```

### 3. 변환 및 출력

```sh
ruby lib/main.rb dsl .github/workflows
```

### 4. GitHub Action으로 사용

`.github/workflows/transform.yml`:

```yaml
name: Transform Ruby DSL to YAML
on:
  push:
    paths:
      - 'dsl/**/*.rb'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Transform Ruby DSL to YAML
        uses: nyanrus/rubi-action@v0
        with:
          dsl: dsl/workflow.rb
          output: .github/workflows/generated.yml
```

## Action Inputs
- `dsl`: 변환할 Ruby DSL 파일 경로 (필수)
- `output`: 생성할 YAML 파일 경로 (기본값: `.github/workflows/generated.yml`)

## 참고
- Ruby DSL 예제: `example.rb`
- 변환 스크립트: `lib/main.rb`, `bin/transform`
