---
layout: post
title: "How to Debug React Applications"
description: "A rundown of debugging React apps: React Developer Tools in the browser, inspecting React Native, and running Jest tests under a real debugger."
date: 2024-09-02 00:00 +0000
categories: [Engineering]
tags: [debugging, react, javascript]
---
<audio controls preload="metadata" src="/assets/audio/how-to-debug-react-applications-summary.ogg">
  Your browser does not support the audio element.
</audio>

Component inspection, prop and state edits, test debugging: here's what actually gets used for debugging React web and React Native applications.

## Debugging with React Developer Tools

### Chrome Extension

React Developer Tools is an invaluable tool for inspecting React components, editing props and state, and identifying performance problems.

1. **Installation**: Install the React Developer Tools browser extension for [Chrome](https://chrome.google.com/webstore/detail/react-developer-tools/fmkadmapgofadopljbjfkapdkoienihi), [Firefox](https://addons.mozilla.org/en-US/firefox/addon/react-devtools/), or [Edge](https://microsoftedge.microsoft.com/addons/detail/react-developer-tools/gpphkfbcpidddadnkolkpfckpihlkkil).

2. **Usage**: Once installed, visit a website built with React, and you will see the _Components_ and _Profiler_ panels, providing insights into the component hierarchy and performance metrics.

### Safari and Other Browsers

For browsers like Safari, you can install the `react-devtools` npm package:

```bash
# Using Yarn
yarn global add react-devtools

# Using Npm
npm install -g react-devtools
```

To use it, add the following `<script>` tag to the beginning of your website’s `<head>`:

```html
<script src="http://localhost:8097"></script>
```

After adding the tag, reload your website in the browser to view it in developer tools.

## Debugging React Native

React Developer Tools can also be used to inspect apps built with React Native.

1. **Global Installation**: Install React Developer Tools globally:

    ```bash
    # Using Yarn
    yarn global add react-devtools

    # Using Npm
    npm install -g react-devtools
    ```

2. **Usage**: Open the developer tools from the terminal, and it should connect to any local React Native app that’s running. If it doesn’t connect immediately, try reloading the app.

## Debugging Tests

### Using `react-scripts`

To debug tests in a React application, you can use the `react-scripts` package with debugging enabled.

1. **Setting Up**: Modify your `package.json` to include a debug script:

    ```json
    {
      "scripts": {
        "test": "react-scripts test",
        "test:debug": "react-scripts --inspect-brk test --runInBand --no-cache"
      }
    }
    ```

2. **Running the Debugger**: Run the test script with debugging enabled:

    ```bash
    $ react-scripts --inspect-brk test --runInBand --no-cache src/component/button/index.test.js
    ```

3. **Connecting the Debugger**: After the debugger starts, open Chrome, type `about:inspect` into the address bar, click `inspect`, and the developer tools will be ready for debugging.

### With an IDE (VS Code or WebStorm)

You can also debug tests directly from an IDE like Visual Studio Code or WebStorm.

1. **Configuration**: Add the following configuration to your `.vscode/launch.json`:

    ```json
    {
      "version": "0.2.0",
      "configurations": [
        {
          "name": "Debug Tests",
          "type": "node",
          "request": "launch",
          "runtimeExecutable": "${workspaceRoot}/node_modules/.bin/react-scripts",
          "args": ["test", "--runInBand", "--no-cache", "--watchAll=false"],
          "cwd": "${workspaceRoot}",
          "protocol": "inspector",
          "console": "integratedTerminal",
          "internalConsoleOptions": "neverOpen",
          "env": { "CI": "true" },
          "disableOptimisticBPs": true
        },
        {
          "name": "Debug Current File",
          "type": "node",
          "request": "launch",
          "runtimeExecutable": "${workspaceRoot}/node_modules/.bin/react-scripts",
          "args": [
            "test",
            "--runInBand",
            "--no-cache",
            "--watchAll=false",
            "${fileDirname}/${fileBasenameNoExtension}"
          ],
          "cwd": "${workspaceRoot}",
          "protocol": "inspector",
          "console": "integratedTerminal",
          "internalConsoleOptions": "neverOpen",
          "env": { "CI": "true" },
          "disableOptimisticBPs": true
        }
      ]
    }
    ```

2. **Debugging**: With the configurations in place, you can start debugging tests directly from the IDE. Set breakpoints beforehand or use the `debugger` statement in your test code.

React Developer Tools covers component inspection for both web and native; the `--inspect-brk` flag and an IDE launch config cover everything that happens inside a test run. Between the two, most React bugs are visible without adding a single `console.log`.
