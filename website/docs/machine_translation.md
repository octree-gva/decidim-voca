---
sidebar_position: 3
slug: /machine-translation
title: Machine Translation
description: How minimal machine translation with Deepl works on voca
---

# General overview
[Decidim Machine Translation](https://docs.decidim.org/en/develop/develop/machine_translations.html) in Decidim can be configured with any translation backend you want. They work this way: 

1. In the admin side only the `default` language is required
2. In the admin side, if there is an empty value for one of the available language, machine translation will be done and the admin field will be kept empty. 
3. If an admin define a translation, it will takes priority over the machine translated content. 

**Tradeoffs we want to attend** 
- If an admin specified a custom translation, it get **fast** out-of sync (as there is no notice original string get updated)
- If you want your plateform in 15+languages, this is a lot of overload in the admin side.
- Machine translation is not always good, specially for small texts as they lack _context_

**Voca solution**  
We call our solution a "minimalistic" machine translation, as we will remove features more than adding.

When machine translation is activate: 
- All other languages won't be displayed in the admin side. The values in other languages will always be saved "empty" to let machine translation do its job
- In the admin side, you do not see any locale chooser. It looks like you edit only one language.

# Setup
First, you need to setup the `available_locales` for your Decidim installation. 
You can set it up through environment variables, or in the `intializers/decidim.rb`. 
```bash
bundle exec rails c
Decidim.available_locales # List of available languages
```
Then access to `/system` and create your organization. You won't see any machine translation settings, that's normal. 
Once created, you can set this new organization to use machine translation: 
```bash 
Decidim::Organization.last.update(
  enable_machine_translations: true,
  machine_translation_display_priority: "translation"
)
```

Last step, you need to [get a Deepl API token](https://www.deepl.com/en/your-account/keys) and set the environment variable `DECIDIM_DEEPL_API_KEY`. A credit card and a subscription is required for most of the cases.

Once you have done this, restart the server.

## Screenshots
**Admin side with machine translated language**
![]()


### Use the Machine Translation without a minimalist approach
If the minimalistic approach does not fit to your project, you can disable it through a configuration in 
an initializer. 
```rb
Decidim::Voca.configure do |config|
  config.enable_minimalistic_deepl = false
end
``` 
And restart your server

### Test translations without actually call deepl
For testing purpose, you can setup the environment variable `VOCA_DUMMY_TRANSLATE` to `true`. This will avoid calling deepl and render
a debug text every time the machine translation is called. (You can then setup `DECIDIM_DEEPL_API_KEY` to whatever)

```
# Example of debug text
DUMMY TRANSLATION [date=12/02/2025 14:05:16,mode=html,context="This is a text from a participatory platform organized in space and then components. \n - Plateform Name: My participatory plateform\n - Plateform Description: undefined\n - space title: My process \n- space description: undefined\n - component name: Proposals\n - Author nickname: doctolib\n- Author bio: Medics @doctolib "]
```

You can then check: 
- If updates does update the date of the translation
- The mode is correct (text/html)
- The context is right
