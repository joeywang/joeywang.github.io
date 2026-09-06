---
layout: post
title: "Upgrading React 17 to 18: Root API, Batching, and Test Fixes"
description: "What changes when you upgrade React 17 to 18: the new root API, automatic batching, Strict Mode's double-invoked effects, and test setup fixes."
date: 2024-10-05 23:51 +0100
categories: [Engineering]
tags: [react, javascript, testing]
---
<audio controls preload="metadata" src="/assets/audio/comprehensive-guide-upgrading-react-from-17-to-18-summary.ogg">
  Your browser does not support the audio element.
</audio>


React 18's headline change for most apps isn't a feature, it's the new root API: `ReactDOM.render` is deprecated in favor of `createRoot`, and that one swap is what turns on automatic batching, concurrent rendering, and Strict Mode's double-invoked effects. Here's what breaks and what to fix when you make that swap.

## Updating dependencies

```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-redux": "^8.0.5"
  },
  "devDependencies": {
    "@cfaester/enzyme-adapter-react-18": "^0.8.0"
  }
}
```

```bash
npm install react@18.2.0 react-dom@18.2.0 react-redux@8.0.5
npm install --save-dev @cfaester/enzyme-adapter-react-18@0.8.0
npm uninstall @wojtekmaj/enzyme-adapter-react-17
```

## Fixing the test setup

`TextEncoder`/`TextDecoder` go missing in some test environments after the upgrade. Add them to `src/setupTests.js`:

```javascript
import { TextEncoder, TextDecoder } from 'util';
global.TextEncoder = TextEncoder;
global.TextDecoder = TextDecoder;
```

If you're on Enzyme, swap the adapter in the same file:

```javascript
import { configure } from 'enzyme'
import Adapter from '@cfaester/enzyme-adapter-react-18'

configure({ adapter: new Adapter() })
```

## Switching to the root API

```javascript
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';

const container = document.getElementById('root');
const root = createRoot(container);
root.render(<App />);
```

This replaces `ReactDOM.render()`.

## What the new root API changes

- **Automatic batching**: state updates are now batched even inside promises, timeouts, and native event handlers, not just inside React event handlers. Code that relied on a state update applying synchronously, right after the call that triggered it, needs to account for that.
- **Strict Mode double-invokes effects**: mount, unmount, mount, specifically to surface effects that don't clean up after themselves. A `useEffect` that was quietly leaking a subscription or a timer becomes visible here.
- **New hooks** become available: `useId`, `useTransition`, `useDeferredValue`. Nothing forces you to adopt them immediately.
- **`act()`'s behavior changed slightly.** If a test suite leaned on its exact semantics, expect a few assertions to need adjusting.

## The upgrade order that works

Switch the root API call first, since it's what the rest of the migration hinges on, then run the test suite and fix whatever Strict Mode's double-invoked effects expose. Most of what looks like a React 18 bug is actually an effect that was already leaking a subscription or a timer; the framework just started telling you.
