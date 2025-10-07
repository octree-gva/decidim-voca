---
sidebar_position: 200
slug: /contribute
title: Contribution
description: How to contribute to the module
---


## Documentation

To contribute to documentation, you need to create documentation files in `/website/docs`, following the current strategy: 

- Be as flat as possible
- Include 3 sections: a general perspective, a deeper documentation about the subject, a reference section

### Install documentation 
To start the documentation website
```bash
cd website
yarn
yarn start
```

If you need to make explanatory schemas, we use [structurizr](https://structurizr.com/), following the [C4 model](https://c4model.com/)

- Schemas: `./website/static/c4`
- Generates the schemas running `./website/bin/c4` (this will creates images in `./website/static/c4/images`)
- Use the generated documentation schemas: `![Infrastructure adaptation](/c4/images/structurizr-cache-infra.png)`


### Build documentation
Before making a documentation contribution, be sure it build, by running `cd website && yarn build`
