# Federails

Federails is an engine that brings ActivityPub to Ruby on Rails application.

## Community

You can join the [matrix chat room](https://matrix.to/#/#federails:matrix.org) to chat with humans.

Open issues or feature requests on the [issue tracker](https://gitlab.com/experimentslabs/federails/-/issues)

## Features

This engine is meant to be used in Rails applications to add the ability to act as an ActivityPub server.

As the project is in an early stage of development we're unable to provide a clean list of what works and what is missing.

The general direction is to be able to:

- publish and subscribe to any type of content
- have a discovery endpoint (`webfinger`)
- have a following/followers system
- implement all the parts of the (RFC) labelled with **MUST** and **MUST NOT**
- implement some or all the parts of the RFC labelled with **SHOULD** and **SHOULD NOT**
- maybe implement the parts of the RFC labelled with **MAY**

## Supported Ruby on Rails versions

This gem is tested against non end-of-life versions of Ruby and Rails:

- Ruby versions 3.1 to 3.4
- Rails 7.1 to 8.0.x.

Feel free to open an issue if we missed something

It _may_ work on other versions, but we won't provide support.

## Documentation

- [Usage](docs/usage.md)
- [Common questions](docs/faq.md)
- [Contributing](CONTRIBUTING.md)

## Extensions

Extensions extends the features of Federails.

- [Federails Moderation](https://github.com/manyfold3d/federails-moderation/)
  > A gem that provides moderation capabilities for Federails

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) to have an overview of the process and the tools we use.

### Contributors

- [echarp](https://gitlab.com/echarp)
- [James Smith](https://gitlab.com/floppy.uk)
- [Manuel Tancoigne](https://gitlab.com/mtancoigne)
- [pessi-v](https://github.com/pessi-v)

### Indirect contributions

- Gitlab runners are graciously provided by [Coopaname](https://coopaname.coop), a French cooperative.
