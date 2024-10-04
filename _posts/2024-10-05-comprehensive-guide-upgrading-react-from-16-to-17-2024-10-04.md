---
layout: post
title: 'Comprehensive Guide: Upgrading React from 16 to 17 2024-10-04'
date: 2024-10-05 00:40 +0100
tags: [react, upgrade]
---
# Comprehensive Guide: Upgrading React from 16 to 17

React 17 brought several changes that, while not introducing many new features, laid the groundwork for future improvements. This guide will walk you through the process of upgrading your React application from version 16 to 17, covering package updates, testing modifications, and common issues you might encounter.

## 1. Upgrade Helper

Before diving into the upgrade process, it's worth mentioning the React Native Upgrade Helper:

[React Native Upgrade Helper](https://react-native-community.github.io/upgrade-helper/)

This tool can provide valuable insights into the changes required for your specific project.

## 2. Updating Node Modules

The first step in the upgrade process is to update your package.json file with the new versions of React and related packages.

```diff
-   "react": "^16.9.0",
+   "react": "^17.0.2",

-   "react-dom": "^16.9.0",
+   "react-dom": "^17.0.2",

-   "react-scripts": "^3.2.0",
+   "react-scripts": "^5.0.1",

-   "jest-fetch-mock": "^2.1.1",
+   "jest-fetch-mock": "^3.0.0",

+   "@babel/plugin-proposal-private-property-in-object": "^7.21.11",

-   "enzyme-adapter-react-16": "^1.14.0",
+   "@wojtekmaj/enzyme-adapter-react-17": "^0.4.1",

-   "enzyme": "^3.10.0",
+   "enzyme": "^3.11.0",
```

After updating these dependencies, run `npm install` or `yarn install` to install the new versions.

## 3. Fixing Tests

### 3.1 Use `beforeEach` instead of `beforeAll`

In your test files, replace `beforeAll` with `beforeEach` to ensure a fresh setup for each test:

```diff
    describe('index edge', () => {
-     beforeAll(() => {
+     beforeEach(() => {
```

### 3.2 Jest Changes (from 24 to 27)

#### Mocking with `spyOn`

The behavior of `jest.spyOn` has changed. You now need to explicitly mock the implementation:

```diff
-     jest.spyOn(_, 'shuffle') # call original but not with 27
+     jest.spyOn(_, 'shuffle').mockImplementation((items) => {
+       return items.reverse()
+     })
```

#### Handling `_.once` in multiple tests

To prevent issues with `_.once` across multiple tests, mock it in your test setup:

```diff
+import _ from 'underscore';
+
+jest.mock('underscore', () => ({
+  ...jest.requireActual('underscore'),
+  once: jest.fn(fn => fn) // Replace _.once with a passthrough function
+}));
```

### 3.3 Enabling Jest Fetch Mocks

Update your `setupTests.js` file:

```diff
# setupTests.js
-import fetchMock from 'jest-fetch-mock'
+import { enableFetchMocks } from 'jest-fetch-mock'

-global.fetch = fetchMock
+enableFetchMocks()
```

When mocking responses, use `doMock()`:

```diff
     beforeEach((done) => {
-      fetch.mockResponseOnce(response)
+      fetch.doMock().mockResponseOnce(response)
       _request(dispatch).then(done)
     })
```

## 4. Fixing ESLint Warnings

### 4.1 Update `.eslintrc`

Add the following rules to your `.eslintrc` file:

```json
{
  "rules": {
    "import/no-anonymous-default-export": ["error", {
      "allowArray": false,
      "allowArrowFunction": false,
      "allowAnonymousClass": false,
      "allowAnonymousFunction": false,
      "allowCallExpression": false,
      "allowNew": false,
      "allowLiteral": false,
      "allowObject": true
    }]
  }
}
```

To automatically fix ESLint issues, you can use this command:

```bash
npx eslint --fix --ext .js,.jsx src|grep .js> files; vim `cat files|sort|tr '\n' ' '`
```

### 4.2 Refactor Default Exports

Replace anonymous default exports with named exports:

```diff
-export default {
+const actions = {
   get: getConfiguration,
 }
+
+export default actions
```

### 4.3 Remove Unused Imports

Clean up your imports by removing unused ones:

```diff
-import { CORRECT, INCORRECT } from '../../../../../constants'
+import { CORRECT } from '../../../../../constants'
```

## Conclusion

Upgrading from React 16 to 17 involves several steps, from updating dependencies to modifying your test setup and addressing ESLint warnings. While the process may seem daunting, following this guide should help you navigate the upgrade smoothly. Remember to thoroughly test your application after the upgrade to ensure everything works as expected.

For more detailed information on the changes in React 17, refer to the [official React 17 release notes](https://reactjs.org/blog/2020/10/20/react-v17.html).
