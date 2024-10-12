---
layout: post
title: Passing Sass Variables When Building Web Apps
date: 2024-10-10 00:00 +0000
---

# Passing Sass Variables When Building Web Apps

In our project, scrom-wrapper is using the training-components library. We want to implement a flexible theming system by changing the primary color in training-components. This article explains how we can set environment variables during the build process of scorm-wrapper to customize the primary color of the imported training-components.

## Why We Want to Pass Variables When Building

Passing Sass variables during the build process offers several advantages:

1. **Flexibility**: It allows us to change the theme without modifying the source code.
2. **Reusability**: The same components can be used with different themes in various projects.
3. **Separation of Concerns**: Theme configuration is separated from component logic.
4. **Build-time Efficiency**: Variables are resolved at build time, ensuring no runtime overhead.

## How to Implement This

### 1. Make the Primary Color Dynamic

First, we need to make our primary color variable in the Sass files dynamic:

```sass
$primary-color: #19a950 !default;
$primary-color-light: lighten($primary-color, 10%);
```

The `!default` flag means this value will be used only if `$primary-color` hasn't been defined elsewhere.

### 2. Pick Up Options from Environment Variables

In your webpack configuration, add logic to parse the `SASS_OPTIONS` environment variable:

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

### 3. Configure Webpack to Use These Options

Modify your webpack configuration to use these options:

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

## How to Debug

### Hard Coding for Testing

To test if the system works, you can first hard-code the primary color in your webpack config:

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

### Logging Processed Files

To see which files are being processed and what variables are being injected, you can use a function for `additionalData`:

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

### Debugging Sass

As a last resort to confirm if the primary color is set when compiling, you can add this Sass code to your main stylesheet:

```sass
@if (variable-exists(primary-color)) {
  @error "Primary color is defined as #{$primary-color}";
} @else {
  @error "Primary color is not defined!";
}
```

This will cause the Sass compilation to fail and output an error message, which can be useful for debugging.

## Putting It All Together

Once everything is set up, you can customize the primary color when building your project like this:

```bash
SASS_OPTIONS='{"additionalData":"$primary: #ff216a;"}' npm run build
```

This command sets the `SASS_OPTIONS` environment variable with a JSON string that defines the `additionalData` to be injected into every Sass file. The build process will then use this to override the default primary color.

By implementing this system, we've created a flexible theming solution that allows easy customization of the primary color (and potentially other variables) without modifying the source code of either scrom-wrapper or training-components.
