---
layout: post
title: "Upgrading React 16 to 17: Dependencies, Jest, and ESLint Fixes"
description: "A practical walkthrough of upgrading a React 16 app to React 17, covering dependency updates, Jest and Enzyme test fixes, and new ESLint warnings."
date: 2024-10-05 00:40 +0100
categories: [Engineering]
tags: [react, javascript, testing, debugging]
---
<audio controls preload="metadata" src="/assets/audio/comprehensive-guide-upgrading-react-from-16-to-17-2024-10-04-summary.ogg">
  Your browser does not support the audio element.
</audio>


React 17 doesn't add much on its own; it exists to make React 18's concurrent rendering possible without forcing every app to jump straight there. Upgrading is mostly dependency bumps and test cleanup, but a few of the failures are non-obvious enough to be worth writing down.

## Updating dependencies

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

Run `npm install` (or `yarn install`) after updating `package.json`.

## Fixing tests

### `beforeAll` to `beforeEach`

Tests that shared setup across cases via `beforeAll` need `beforeEach` instead, or state from one test leaks into the next:

```diff
    describe('index edge', () => {
-     beforeAll(() => {
+     beforeEach(() => {
```

### Jest 24 to 27

`jest.spyOn` no longer calls the original implementation by default; you have to mock it explicitly:

```diff
-     jest.spyOn(_, 'shuffle') # call original but not with 27
+     jest.spyOn(_, 'shuffle').mockImplementation((items) => {
+       return items.reverse()
+     })
```

`_.once` needs mocking in test setup, or the "only runs once" behavior bleeds across tests that expect a fresh call each time:

```diff
+import _ from 'underscore';
+
+jest.mock('underscore', () => ({
+  ...jest.requireActual('underscore'),
+  once: jest.fn(fn => fn) // Replace _.once with a passthrough function
+}));
```

### Enabling Jest fetch mocks

`setupTests.js` needs the new import and an explicit enable call:

```diff
# setupTests.js
-import fetchMock from 'jest-fetch-mock'
+import { enableFetchMocks } from 'jest-fetch-mock'

-global.fetch = fetchMock
+enableFetchMocks()
```

Mocked responses now go through `doMock()`:

```diff
     beforeEach((done) => {
-      fetch.mockResponseOnce(response)
+      fetch.doMock().mockResponseOnce(response)
       _request(dispatch).then(done)
     })
```

## Fixing ESLint warnings

Add this rule to `.eslintrc` to catch anonymous default exports:

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

To autofix what ESLint can fix:

```bash
npx eslint --fix --ext .js,.jsx src|grep .js> files; vim `cat files|sort|tr '\n' ' '`
```

Replace anonymous default exports with named ones:

```diff
-export default {
+const actions = {
   get: getConfiguration,
 }
+
+export default actions
```

Clean up imports that are now unused:

```diff
-import { CORRECT, INCORRECT } from '../../../../../constants'
+import { CORRECT } from '../../../../../constants'
```

## The pattern

Most of what breaks on a 16-to-17 bump isn't React itself, it's Jest and Enzyme catching up to it: `beforeAll` sharing state where you meant `beforeEach`, `spyOn` losing its automatic passthrough, and fetch mocks needing an explicit `enableFetchMocks()` call. None of it is hard to fix once you know to expect it; the point of writing it down is not having to rediscover it project by project.
