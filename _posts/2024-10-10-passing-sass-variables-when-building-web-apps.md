---
layout: post
title: "Passing Sass Variables at Build Time with Webpack"
description: "How to inject a Sass variable, like a theme's primary color, at build time using a SASS_OPTIONS environment variable and a custom webpack additionalData function."
date: 2024-10-10 00:00 +0000
categories: [Engineering]
tags: [javascript, css, webpack, debugging]
---

<audio controls preload="metadata" src="/assets/audio/passing-sass-variables-when-building-web-apps-summary.ogg">
  Your browser does not support the audio element.
</audio>


In our project, `scorm-wrapper` imports a shared `training-components` library and needs to override its primary color per deployment, without forking the library or hardcoding a color into its source. Passing a Sass variable at build time does that: the theme lives outside both codebases, in an environment variable set when `scorm-wrapper` is built.

## Making the variable overridable

```sass
$primary-color: #19a950 !default;
$primary-color-light: lighten($primary-color, 10%);
```

`!default` means this value only applies if `$primary-color` hasn't already been set elsewhere, which is what makes it overridable from the build.

## Reading the override from an environment variable

In the webpack config, parse a `SASS_OPTIONS` environment variable:

```javascript
const getSassOptions = () => {
  if (process.env.SASS_OPTIONS) {
    try {
      return JSON.parse(process.env.SASS_OPTIONS);
    } catch (error) {
      console.warn('Failed to parse SASS_OPTIONS:', error);
      console.warn('Falling back to default sass options');
    }
  }
  return {};
};

const sassOptions = getSassOptions();
```

Wire it into the sass-loader config:

```javascript
{
  test: sassRegex,
  use: [
    {
      loader: require.resolve(`sass-loader`),
      options: {
        sourceMap: true,
        sassOptions: { outputStyle: 'expanded' },
        additionalData: '$primary: #33216a;'
      },
    }
  ]
  sideEffects: true,
},
```

## Debugging when the override doesn't take

Hardcode the value first, to confirm the wiring works before trusting the environment variable:

```javascript
{
  loader: require.resolve(`sass-loader`),
  options: {
    sourceMap: true,
    sassOptions: { outputStyle: 'expanded' },
    additionalData: '$primary: #33216a;'
  },
},
```

To see exactly which files are being processed and what gets injected into each, use a function instead of a static string for `additionalData`:

```javascript
{
  loader: require.resolve(`sass-loader`),
  options: {
    sourceMap: true,
    sassOptions: { outputStyle: 'expanded' },
    additionalData: (content, loaderContext) => {
      console.log('Processing:', loaderContext.resourcePath);
      return `$primary-color: #007bff;\n${content}`;
    },
  },
},
```

As a last resort, force the Sass compiler to say what it thinks the variable is:

```sass
@if (variable-exists(primary-color)) {
  @error "Primary color is defined as #{$primary-color}";
} @else {
  @error "Primary color is not defined!";
}
```

This fails the build and prints the value, or its absence, which is the fastest way to tell whether the problem is on the Sass side or the webpack side.

## Using it

```bash
SASS_OPTIONS='{"additionalData":"$primary: #ff216a;"}' npm run build
```

The environment variable carries a JSON string with the `additionalData` to inject into every Sass file compiled in that build, which is what lets `scorm-wrapper` theme `training-components` without touching either one's source.
