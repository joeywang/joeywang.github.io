---
layout: post
title: "Xiaomi \"No Signal\": Dialer Codes to ADB Logs"
description: "How to debug a \"No Signal\" or \"No SIM\" error on a Xiaomi phone, from dialer diagnostic codes through ADB logcat filters to EFS partition failures."
date: 2025-03-19
tags: [android, debugging, adb, networking]
categories: [Notes]
---

<audio controls preload="metadata" src="/assets/audio/debug-xiaomi-sim-summary.ogg">
  Your browser does not support the audio element.
</audio>

## Debugging "No Signal" on a Xiaomi Device

A "No SIM" or "No Signal" error on a Xiaomi phone stops mobile communication outright. Rebooting or re-inserting the SIM fixes the easy cases. When those don't work, the built-in diagnostic dialer codes and ADB get you further.

-----

### Phase 1: The groundwork

1. **SIM card:**
   * Remove it and check the gold contacts for scratches or dirt; check the tray too.
   * Put it in another known-working phone. If it fails there, the SIM itself is bad: contact the carrier.
   * Put a different, known-working SIM in your Xiaomi. If that one works, the problem is your original SIM or carrier settings tied to it.
2. **Carrier and account:**
   * Confirm the account is in good standing.
   * Check for reported local outages.
   * Confirm the device isn't blacklisted and supports your carrier's bands, especially on an imported model.
3. **Software and settings:**
   * `Settings > About phone > MIUI version`: check for a pending update; these often carry modem/radio firmware.
   * `Settings > Connection & sharing > Reset Wi-Fi, mobile networks, and Bluetooth`: clears saved network config.
   * `Settings > SIM cards & mobile networks > [Your SIM] > Mobile networks`: toggle automatic vs. manual network selection.
   * `Preferred network type`: try forcing 3G if 4G/5G registration looks unstable.

-----

### Phase 2: Dialer diagnostic codes

1. **CIT (hardware test) menu**
   * Code: `*#*#64663#*#*` (or `*#*#6484#*#*`).
   * Runs the hardware test suite, including a SIM card test that reports whether the card is detected.
   * If the code doesn't work: `Settings > About phone > All specs`, tap "Kernel version" 5–7 times.

2. **Testing menu (phone information)**
   * Code: `*#*#4636#*#*`.
   * Shows current network, signal strength (dBm and asu: closer to 0 is better), voice/data network type, IMEI, and a ping test.

3. **IMEI check**
   * Code: `*#06#`.
   * A null or obviously wrong IMEI points to a corrupted EFS partition: a serious problem, not a settings one.

**Reading the results:** CIT reporting the SIM as absent, after you've confirmed the SIM works elsewhere, points to the SIM reader or motherboard. Fluctuating signal strength in the testing menu points to the antenna or modem. "Emergency calls only" means the phone can't complete network registration.

-----

### Phase 3: ADB

**Setup:** install Android SDK Platform Tools, enable Developer Options (tap MIUI version 7–10 times), enable USB debugging, connect and authorize.

**`adb devices`** confirms the device is recognized before anything else.

**`adb logcat`**, filtered, is the most useful single tool here:

```bash
adb logcat -E "RILJ|Radio|Telephony|GSM|SignalStrength|SIM|Modem|DataConnection|NetworkController"
```

Look for RIL errors (`RIL_REQUEST_SETUP_DATA_CALL failed`, `SIM_STATE_ABSENT`, `RADIO_NOT_AVAILABLE`), signal strength swings, network registration attempts, and SIM state transitions (`SIM_STATE_READY`, `SIM_STATE_PIN_REQUIRED`).

**`adb shell dumpsys telephony.registry`** dumps network state, signal strength, cell location, and IMEI in one shot: redirect it to a file, it's dense.

**`adb shell getprop`** pulls specific properties: `gsm.operator.alpha`, `gsm.operator.numeric`, `gsm.network.type`, `gsm.sim.state`, `ril.signalstrength.dbm`.

**`adb bugreport bugreport.zip`** generates a full report (logcat, dumpsys, more) if you need everything at once.

Correlate timestamps with what you were doing on the device (toggling airplane mode, attempting a call) rather than reading the log cold.

-----

### Phase 4: Beyond the phone's settings

* **APN settings** mostly affect data, but a wrong APN can occasionally affect registration too. Check `SIM cards & mobile networks > [Your SIM] > Access Point Names`.
* **Modem firmware** re-flashing is high-risk: wrong firmware can brick the device. Only attempt it with fastboot ROMs or reputable sources, and only if you understand what you're doing.
* **EFS partition** corruption, confirmed by a blank or invalid IMEI, is usually a service-center job. It's not something you fix with a settings reset.

-----

### When it's hardware

Damaged SIM reader, faulty antenna, a bad radio chip, or another motherboard fault. At that point it's an authorized Xiaomi service center or a reputable independent repair shop, not another round of ADB commands.

### The takeaway

Dialer codes handle the quick hardware checks; ADB and logcat handle everything past that. Work through both before assuming a hardware fault, and back up your data before touching modem firmware or the EFS partition: that's the step that turns a software problem into a paperweight.
