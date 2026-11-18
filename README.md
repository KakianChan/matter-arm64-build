# Matter ARM64 controller builder

This repository builds `_ChipDeviceCtrl.so` for the Linux ARM64
`chip-cert-bins` image from connectedhomeip commit
`e91ea83caae4adb1871aa4bbe93c4be2dd9e1abf` and the
`stale-cache.patch` source changes.

Run the **Build ARM64 Python controller** workflow manually. The resulting
`chip-device-controller-arm64` artifact contains:

- `_ChipDeviceCtrl.so`
- `SHA256SUMS`

The workflow does not need a DUT, Thread radio, OTBR, or Docker.
