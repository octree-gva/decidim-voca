---
sidebar_position: 1
id: homepage
slug: /
---

# How does it work?

Decidim Voca is a gem containing tweaks used at [voca.city](https://voca.city). With gem, you will get: 

- Improvement on geolocated proposals
- Small bugfixes
- General layout improvements
- Performance improvement
- Minimalistic deepl integration for machine translation

## Improvement on geolocated proposals
Inspired by decidim-reporting_proposals, we do add on our instance two buttons: 

1. Find my location on `address` fields: a button next address input that will query current location to fill the address field
2. Take a photo: A shortcurt (usefull on mobile) that will open the camera to upload a new photo attachment to the proposal

## Small Bugfixes

On the footer  
- alignements and headings
- missing translations
- resizing of logos

On user groups  
- Avoid creating user group with bad nicknames

On etherpad
- Stable integration of etherpad, with a better error handling

On user profiles
- Strong validation of nicknames

On proposals  
- Fix proposal serialization when decidim-awesome is installed
- Add "on going" mention on vote column in the admin side

## Next gen images
We generates `webp` images alternatives, using a `<picture>` html tag to: 
- Serve next generation images for browsers who support it
- Fallback to original jpg/png images if not supported. 

Webp images are generated in only a few critical locations: 
- Home page: grid of assemblies/processes
- Propositions cards
- Big image on menu overlay (highlighted space banner)

## Minimalistic Deepl Machine translation
Decidim-voca embbed a deepl machine translation that: 
- Is context wise, giving information of the overall plateform, space and component
- Support HTML machine translation

Once the minimalistic deepl machine translation is enabled, the flow differs from traditional machine translated instances: 

1. In the admin side, you edit text ONLY in the default locale
2. Any attempt to access admin side in another language will redirect.
3. Translated content in other language will ALWAYS be 100% machine translated

To add a new language, some server actions are required: 
- Set up the API key from deepl
- Activate manually the machine translation for the organization
- Run over `i18n-tasks` to translate automatically all decidim locales in the new language
- Restart your server, you are ready. 

