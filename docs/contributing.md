---
title: Contributing
nav_order: 40
---

## Contributing

Contributions are welcome, may it be issues, ideas, code or whatever you want to share. Please note:

- This project is _fast forward_ only: we don't do merge commits
- We adhere to [semantic versioning](). Please update the changelog in your commits
- We try to adhere to [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) principles
- We _may_ rename your commits before merging them
- We _may_ split your commits before merging them

To contribute:

1. Fork this repository
2. Create small commits
3. Ideally create small pull requests. Don't hesitate to open them early so we all can follow how it's going
4. Get congratulated

### Tooling

#### RSpec

RSpec is the test suite. Start it with

```sh
bundle exec rspec
```

#### Rubocop

Rubocop is a linter. Start it with

```sh
bundle exec rubocop
```

#### FactoryBot

FactoryBot is a factory generator used in tests and development.
A rake task checks the replayability of the factories and traits:

```sh
bundle exec app:factory_bot:lint
```
