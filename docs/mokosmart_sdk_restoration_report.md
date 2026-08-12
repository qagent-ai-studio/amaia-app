# Bug report — MKBeaconXDButton iOS SDK: State Restoration

**SDK:** `MKBeaconXDButton` (14-iOS-MKButton-SDK), commit `544268d` — "Add support for restoration"
**Device:** BXP-B-D
**Test platform:** iPhone 12 mini, iOS 18.1.1
**Integration:** Flutter app with a native Swift BLE service
**Date:** 2026-08-12

## Summary

First of all, thank you for adding State Restoration support in `544268d`. We have it
working end to end: iOS now relaunches our terminated app on a BLE event and the
emergency alert is delivered.

Getting there required working around **three issues in the SDK**. All three fail
silently, which made them expensive to diagnose. Each has a small fix on your side and
would save every integrator the same investigation.

---

## Issue 1 — `isLaunchedFromStateRestoration` always returns `NO`

**File:** `MKBXDCentralManager.m:101-145`
**Severity:** the public API is unusable

`enableStateRestorationWithIdentifier:` decides the value by reading a flag from
`NSUserDefaults`:

```objc
BOOL wasTerminated = [defaults boolForKey:@"MKBXD_WAS_TERMINATED"];
if (wasTerminated) {
    g_isLaunchedFromStateRestoration = YES;
}
[defaults setBool:NO forKey:@"MKBXD_WAS_TERMINATED"];
```

**Nothing in the SDK ever writes `YES` to `MKBXD_WAS_TERMINATED`.** We searched the
entire source tree: the key appears only in those two lines — one read, one write of
`NO`. Therefore `g_isLaunchedFromStateRestoration` is never set and
`+isLaunchedFromStateRestoration` always returns `NO`.

**Impact:** integrators cannot tell a restoration launch from a normal launch through
your API.

**Our workaround:** Apple's own launch option, which is reliable:

```swift
let relaunchedForBluetooth = launchOptions?[.bluetoothCentrals] != nil
```

**Suggested fix:** set `MKBXD_WAS_TERMINATED` to `YES` when the app enters the
background with an active central manager (for example on
`UIApplicationDidEnterBackgroundNotification`), or drop the `NSUserDefaults` approach
entirely and derive the value from `UIApplicationLaunchOptionsBluetoothCentralsKey`.

---

## Issue 2 — `willRestoreState` does not notify when only a scan is restored

**File:** `MKBXDBaseCentralManager.m:114-146`
**Severity:** silent loss of the restoration event in a common scenario

The call to `restorationCompletion` sits inside a guard on the peripheral count:

```objc
NSArray<CBPeripheral *> *peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];
if (peripherals.count > 0) {
    // ...
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.restorationCompletion) {
            self.restorationCompletion(peripherals);
        }
        // ...
    });
}
// scan restoration is handled below, but the integrator is never notified
```

iOS can relaunch an app with `CBCentralManagerRestoredStateScanServicesKey` populated
and `CBCentralManagerRestoredStatePeripheralsKey` **empty** — this is exactly what
happens when the tag was out of range and the app only had a scan pending when the
system killed it. Your code correctly restores the scan a few lines below, but
`mk_bxd_didRestoreStateWithPeripherals:` is never called, so the integrator has no way
to know a restoration happened and cannot rebuild its own state.

**Impact:** in that scenario the app is relaunched but stays inert. For an emergency
product this is a silent failure.

**Suggested fix:** invoke `restorationCompletion` unconditionally, passing an empty
array when there are no peripherals. The delegate can then decide what to do.

---

## Issue 3 — the `@optional` restoration delegate silently fails from Swift

**File:** `MKBXDCentralManager.h` (protocol declaration) and `MKBXDCentralManager.m:131`
**Severity:** highest practical impact — correct-looking code does nothing

The protocol declares its only method as optional:

```objc
@protocol mk_bxd_stateRestorationDelegate <NSObject>
@optional
- (void)mk_bxd_didRestoreStateWithPeripherals:(NSArray<CBPeripheral *> *)peripherals;
@end
```

and the SDK guards the call with `respondsToSelector:`:

```objc
if (manager && manager.restorationDelegate &&
    [manager.restorationDelegate respondsToSelector:@selector(mk_bxd_didRestoreStateWithPeripherals:)]) {
    [manager.restorationDelegate mk_bxd_didRestoreStateWithPeripherals:restoredPeripherals ?: @[]];
}
```

In Swift, a method implementing an **optional** requirement of an `@objc` protocol is
not automatically exposed to the Objective-C runtime. Without an explicit `@objc`,
`respondsToSelector:` returns `false` and the SDK skips the call. Because the
requirement is optional, **the Swift compiler emits no error or warning** — the code
compiles, conformance is declared, and the delegate is simply never invoked.

We lost significant time here: our logs showed
`[MKBXD] State restoration completed, restored 1 peripherals` followed by nothing at
all on our side.

The fix on our end was one keyword:

```swift
@objc func mk_bxd_didRestoreState(withPeripherals peripherals: [CBPeripheral]) {
```

**Suggested fix:** declare the method `@required` instead of `@optional`. Swift then
enforces conformance at compile time and exposes the selector automatically. If it
must stay optional, please document the `@objc` requirement prominently — this will
affect every Swift integrator.

---

## Additional observation (not a bug): the ~10 second execution window

Worth documenting for integrators. When iOS relaunches the app for a BLE event it
grants roughly **10 seconds** of execution before suspending it again. In our logs the
app produced no further activity after the wake-up until the next BLE event.

Practical consequence: any reconnection strategy based on timers or exponential
backoff **will not run**. The event that woke the app must be handled immediately, on
the wake-up itself.

This also interacts with your SDK's design. The button press arrives roughly 87 ms
after launch, well before any connection or notification setup can complete, so an
integrator that gates event handling on "connected and initialized" will drop exactly
the event that caused the relaunch.

---

## Test methodology (for reproduction)

Using Xcode's Stop button does **not** terminate the app when Xcode did not launch it;
it stays suspended and produces false positives. A reliable procedure:

```bash
# Launch the app from the home screen (not from a build tool, which reinstalls)
xcrun devicectl device info processes --device "<device>" | grep -i "Runner.app/Runner"
# note PID and container UUID

xcrun devicectl device process terminate --device "<device>" --pid <PID> --kill
xcrun devicectl device info processes --device "<device>" | grep -i "Runner.app/Runner"
# must return nothing

# wait 2-3 minutes, press the button, query the PID again
```

**Pass criterion:** a different PID with the **same container UUID**. A changed
container UUID means the app was reinstalled and the test is invalid.

## Our result

```
PID:       961  ->  993
Container: 14179CB9-2187-4B1E-989A-86AFEEBE496E  (unchanged)
```

```
[MKBXD] State restoration enabled with identifier: cl.mistatas.amaia.want
[MKBXD] willRestoreState called - System is restoring Bluetooth state
[MKBXD] Restoring 1 previously connected peripherals
[MKBXD] State restoration completed, restored 1 peripherals
```

Alert delivered with the app previously terminated. State Restoration in `544268d`
works as intended once the three issues above are worked around.

---

## Summary of requests

| # | Issue | Suggested fix |
|---|---|---|
| 1 | `isLaunchedFromStateRestoration` always `NO` | Write `MKBXD_WAS_TERMINATED`, or derive from `launchOptions` |
| 2 | No notification when only a scan is restored | Call `restorationCompletion` unconditionally with an empty array |
| 3 | `@optional` delegate silently fails from Swift | Declare the method `@required`, or document the `@objc` requirement |

We are happy to test any updated build against the same procedure.
