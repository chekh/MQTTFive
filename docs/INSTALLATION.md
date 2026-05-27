# Installation

## Find your MT5 data directory

Open MetaTrader 5 → File → Open Data Folder. This opens the root of the
MQL5 directory tree. The `Include/` and `Scripts/` subdirectories are where
library files go.

## Option 1: Copy files

```
# From MQTTFive repository root:
cp -r Include/MQTTFive/  <MT5_DATA>/MQL5/Include/MQTTFive/

# Optional: test scripts
cp -r Scripts/MQTTFive/  <MT5_DATA>/MQL5/Scripts/MQTTFive/
```

After copying, the directory structure should look like:

```
MQL5/
  Include/
    MQTTFive/
      MQTTClient.mqh
      MQTTCodec.mqh
      MQTTTypes.mqh
      MQTTBuffer.mqh
      MQTTTransport.mqh
  Scripts/
    MQTTFive/
      TestT01_Connect.mq5
      ...
```

## Option 2: Clone into Include

```bash
cd <MT5_DATA>/MQL5/Include/
git clone https://github.com/chekh/MQTTFive.git MQTTFive
```

Note: this clones the entire repository including `docs/` and `Scripts/`.
Only the `Include/MQTTFive/` subdirectory is used by `#include`. The extra
files won't interfere.

## Option 3: Symlink (development)

```bash
cd <MT5_DATA>/MQL5/Include/
ln -s /path/to/MQTTFive/Include/MQTTFive MQTTFive
```

Useful when developing MQTTFive in a separate directory. Changes to source
files are immediately visible to MT5 without copying.

## Verify installation

Create a test script in MetaEditor (File → New → Script):

```cpp
#property script_show_inputs
#include <MQTTFive/MQTTClient.mqh>

void OnStart()
  {
   MQTTClient client;
   MQTTConnectParams params;
   params.Init();
   params.client_id = "install_test";
   if(client.Connect("127.0.0.1", 1883, params))
      Print("OK: connected");
   else
      Print("FAIL: ", client.GetLastError());
   client.Disconnect();
  }
```

Compile (F7) and run. Expected output with Mosquitto running:

```
OK: connected
```

If you see `FAIL: Transport connect failed`, check that your MQTT broker is
running on `127.0.0.1:1883`.

## Test scripts

15 test scripts are included in `Scripts/MQTTFive/`. To use them:

1. Copy `Scripts/MQTTFive/` to `<MT5_DATA>/MQL5/Scripts/MQTTFive/`
2. Open each script in MetaEditor and compile (F7)
3. In MT5 Navigator panel: Scripts → MQTTFive → drag a test onto a chart
4. Check the Experts tab in Terminal for PASS/FAIL output

All tests require Mosquitto 5.0 running on `127.0.0.1:1883`.

## Troubleshooting

### "Cannot open include file"

MT5 cannot find the library files. Verify:
- `MQTTClient.mqh` exists at `<MT5_DATA>/MQL5/Include/MQTTFive/MQTTClient.mqh`
- The `#include` path uses angle brackets: `#include <MQTTFive/MQTTClient.mqh>`

### "Transport connect failed"

The broker is not reachable. Verify:
- Mosquitto is running: `mosquitto -v` (verbose mode)
- Port 1883 is correct
- Firewall is not blocking
- If using a remote broker, use the correct IP/hostname

### Compilation errors about types

Make sure you're using the latest version of all 5 `.mqh` files. They must
all be from the same release — mixing old and new files causes type mismatches.

### Socket operations fail in Strategy Tester

MQL5 Socket functions (`SocketCreate`, `SocketConnect`) are not available
in the Strategy Tester. MQTTFive only works in live charts or scripts.
