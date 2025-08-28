---
sidebar_position: 4
slug: /weglot
title: Weglot Integration
description: How to use pre-configured weglot setup
---

# Weglot
`decidim-voca` have pre-configuration for a transparent uses of weglot.
Weglot integration works with `subdirectories` integration. 

## Setup weglot account

To setup your weglot configuration, you will need to follow these steps: 

1. Create a weglot account
2. Create a project
  1. Setup your DNS to let your main domain point to weglot
  2. Add a TXT DNS entry as weglot ask you
  3. "Check DNS" and wait around 10min
  4. Copy the `api_key` given from the initialization script Weglot gives you
  5. Add the api_key in `WEGLOT_API_KEY` in environment variables
  6. Restart your server

:::info
Weglot integration is not compatible with Decidim multi-tenant for now, as 
we share the same API key for the whole serveer
:::

## Environment Variables
We use environment variables to configure the module: 

| Variable | Description | Default | Options |
|----------|-------------|---------|---------|
| `WEGLOT_API_KEY` | Api key for weglot | `` | string |

## How it works
There is no changes needed with the infrastructure, as the request goes first to 
Weglot servers (protected with Cloudflare), and then redirect back to your instance.  

<center>
![Infrastructure with Weglot](/c4/images/structurizr-weglot-infra.png)
</center>

Once the request arrives to Weglot, it will strip the locale subdirectory prefix, and display content.  

<center>
![Translation logics](/c4/images/structurizr-weglot-translation-logics.png)
</center>


The content will be _always_ cached by weglot, and updated in the background ["from time to time"](https://developers.weglot.com/javascript/options#cache)

## References

- [Javascript initialization](https://developers.weglot.com/javascript/options)
- [Custom Switcher](https://developers.weglot.com/javascript/link-hooks#example-create-your-own-switcher)
