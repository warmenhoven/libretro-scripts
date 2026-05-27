# ROM Sync Runbook

## Devices

| Device       | Method   | Notes                        |
|--------------|----------|------------------------------|
| Mac          | (source) | Primary collection           |
| NAS          | rsync    | Synology, ssh enabled        |
| iPhone       | WebDAV   | RetroArch built-in server    |
| iPad         | WebDAV   | RetroArch built-in server    |
| AppleTV (x3) | WebDAV   | RetroArch built-in server    |

## Source location
```bash
ROM_DIR=~/Documents/RetroArch/roms
```

## Sync to NAS
```bash
rsync -n -avz --exclude .DS_Store --exclude @eaDir "$ROM_DIR/" fillmore:roms/
```

## Sync to iOS/tvOS devices (WebDAV)

RetroArch WebDAV server runs on port 8080 by default when enabled.
```bash
# Replace with device's name (hostname)
IPHONE_NAME=iPhone-17-Pro

# Using rclone (probably cleanest for bulk)
rclone sync "$ROM_DIR" :webdav: --webdav-url="http://$IPHONE_NAME.local:8080"
```

## Pull from iOS/tvOS (WebDAV)
```bash
DEVICE_NAME=iPhone-17-Pro

# Copy everything from device
rclone -n copy :webdav: "$ROM_DIR" --webdav-url="http://$DEVICE_NAME.local:8080/roms"
```

## Push to iOS/tvOS (WebDAV)
```bash
# Copy full collection to device
rclone -n copy "$ROM_DIR" :webdav: --webdav-url="http://$DEVICE_NAME.local:8080/roms"
```
