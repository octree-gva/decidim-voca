# Website

This website is built using [Docusaurus](https://docusaurus.io/), a modern static website generator.

### Installation
Make sure you have node and docker. You can then run: 
```
$ yarn
```

### Local Development

```
$ yarn start
```

This command starts a local development server and opens up a browser window. Most changes are reflected live without having to restart the server.

To build c4 model schemas images, you need to `./bin/create-c4` manually (the bin do not support watch option yet)

### Build

```
# Generates schemas
./bin/create-c4
# Build website
yarn build
```

This command generates static content into the `build` directory and can be served using any static contents hosting service.

### Deployment

Using SSH:

```
$ USE_SSH=true yarn deploy
```

Not using SSH:

```
$ GIT_USER=<Your GitHub username> yarn deploy
```

If you are using GitHub pages for hosting, this command is a convenient way to build the website and push to the `gh-pages` branch.
