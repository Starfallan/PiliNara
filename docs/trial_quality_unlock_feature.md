# Trial/VIP Quality Unlock Feature

## Overview

This feature implements client-side quality unlock functionality, allowing non-VIP users to access high-quality streams when the server returns accessible URLs. This is an experimental feature for technical learning and research purposes.

## Implementation Details

### Reference
This implementation references the approach used in BiliRoamingX:
- [VideoQualityPatch.java](https://github.com/BiliRoamingX/BiliRoamingX/blob/ae58109f3acdd53ec2d2b3fb439c2a2ef1886221/integrations/app/src/main/java/app/revanced/bilibili/patches/VideoQualityPatch.java)
- [TrialQualityPatch.java](https://github.com/BiliRoamingX/BiliRoamingX/blob/main/integrations/app/src/main/java/app/revanced/bilibili/patches/TrialQualityPatch.java#L22-L44)
- [PlayURLPlayViewUGC.kt](https://github.com/BiliRoamingX/BiliRoamingX/blob/main/integrations/app/src/main/java/app/revanced/bilibili/patches/protobuf/hooks/PlayURLPlayViewUGC.kt#L58-L60)
- [BangumiPlayUrlHook.kt](https://github.com/BiliRoamingX/BiliRoamingX/blob/main/integrations/app/src/main/java/app/revanced/bilibili/patches/protobuf/BangumiPlayUrlHook.kt#L110-L120)

### Key Changes

#### 1. Settings Integration
- **File**: `lib/utils/storage_key.dart`
  - Added `enableTrialQuality` setting key

- **File**: `lib/utils/storage_pref.dart`
  - Added `enableTrialQuality` getter with default value `false`

- **File**: `lib/pages/setting/models/video_settings.dart`
  - Added switch control with risk warning dialog
  - Default: OFF (disabled by default for safety)
  - Shows compliance warning when enabling

#### 2. Core Unlock Logic
- **File**: `lib/http/video.dart`
  - Added `_makeVipFreePlayUrlModel()` function
  - Added `_hasPlayableUrls()` helper function
  - Integrated into `videoUrl()` method
  - Processes dash video/audio streams and durl (legacy format)
  - Logs available streams for debugging

### How It Works

1. **Request Phase** (Already implemented):
   - `fnval=4048`: Request all video formats
   - `fourk=1`: Request 4K support
   - `try_look=1`: Request trial access (for non-logged-in users)

2. **Response Processing**:
   - When enabled, scans all returned video/audio streams
   - Identifies streams with valid playable URLs
   - Logs stream information for debugging
   - Note: The Dash format in PiliPlus doesn't use `needVip` flags in the same way as gRPC responses

3. **Playback**:
   - Player/downloader automatically uses available streams
   - Higher quality streams are accessible if URLs are present

## Usage

### Enable the Feature

1. Open Settings → Audio/Video Settings (音视频设置)
2. Find "解锁试用/会员画质" (Unlock Trial/VIP Quality)
3. Toggle the switch ON
4. Read and accept the risk warning dialog
5. The feature is now enabled

### Disable the Feature

1. Open Settings → Audio/Video Settings
2. Toggle "解锁试用/会员画质" OFF

### View Debug Logs

When the feature is enabled and running in debug mode:
1. Check console output for `[UnlockQuality]` prefixed messages
2. Logs show:
   - Video stream quality codes and codecs
   - Audio stream quality
   - URL availability
   - Total streams processed

## Testing

### Test Environment Setup

1. Use a non-VIP Bilibili account
2. Enable debug mode (development build)
3. Enable the trial quality unlock feature in settings

### Manual Test Steps

#### Test Case 1: UGC Video (User-Generated Content)
1. Navigate to a regular user video (BV/AV number)
2. Open the video player
3. Check console logs for `[UnlockQuality]` messages
4. Verify available quality options include:
   - 1080P (if available)
   - Higher quality formats if server returns them
5. Select and play different quality options

#### Test Case 2: PGC Content (Bangumi/Anime)
1. Navigate to a PGC episode (ep_id)
2. Open the video player
3. Check console logs for stream information
4. Verify quality options
5. Test playback

#### Test Case 3: Download Functionality
1. Select a video to download
2. Enable the unlock feature
3. Choose quality settings
4. Initiate download
5. Verify higher quality options are available

### Expected Behavior

#### With Feature ENABLED:
- Console logs show `[UnlockQuality]` messages
- Available streams are logged with details
- All streams with valid URLs are accessible
- Higher quality options may appear in quality selector

#### With Feature DISABLED:
- No unlock processing occurs
- Normal quality restrictions apply
- No `[UnlockQuality]` debug messages

### Sample Response Structure

#### Dash Video Stream Example:
```dart
[UnlockQuality] Video stream available: quality=116, codec=avc1.640032, url=https://...
[UnlockQuality] Video stream available: quality=112, codec=avc1.640028, url=https://...
```

#### Dash Audio Stream Example:
```dart
[UnlockQuality] Audio stream available: quality=高音质, url=https://...
[UnlockQuality] Audio stream available: quality=杜比全景声, url=https://...
```

#### Legacy Durl Format Example:
```dart
[UnlockQuality] Durl stream available: order=1, size=12345678, url=https://...
```

## Risk Warnings and Compliance

### ⚠️ Important Notices

1. **Educational Purpose Only**: This feature is for technical learning and research purposes only.

2. **No Content Cracking**: This does not decrypt or bypass DRM protection. It only allows playback of streams where the server already returns accessible URLs.

3. **User Responsibility**: Users must understand and accept the risks. This may violate Bilibili's Terms of Service.

4. **Default Disabled**: The feature is OFF by default and requires explicit user opt-in with acknowledgment.

5. **Compliance**: 
   - Do not use this feature to circumvent legitimate payment requirements
   - Respect content creators and platform policies
   - Use responsibly for educational purposes only

6. **No Warranty**: This feature is provided as-is without any warranties. Use at your own risk.

## Implementation Notes

### Architecture Decisions

1. **Non-Intrusive**: The unlock function only processes data; it doesn't modify network requests or bypass security measures.

2. **Conditional Execution**: Only runs when explicitly enabled by the user.

3. **Debug Logging**: Comprehensive logging for development and debugging purposes.

4. **Graceful Handling**: Errors in unlock processing don't affect normal playback.

### Code Structure

```
lib/
├── utils/
│   ├── storage_key.dart          # Setting key definition
│   └── storage_pref.dart          # Setting access
├── pages/setting/models/
│   └── video_settings.dart        # UI control with warning
└── http/
    └── video.dart                 # Core unlock logic
```

### Future Enhancements (Potential)

1. **gRPC Support**: Extend to handle gRPC/protobuf responses with `StreamInfo.needVip` and `StreamInfo.vipFree` fields
2. **Stream Filtering**: Add UI to show which streams were unlocked
3. **Statistics**: Track unlock success rate
4. **A/B Testing**: Compare quality availability with/without feature

## Troubleshooting

### Feature Not Working

1. **Check Settings**: Ensure the feature is enabled in Settings → Audio/Video Settings
2. **Check Logs**: Look for `[UnlockQuality]` messages in debug console
3. **Network Issues**: Verify that the video loads normally first
4. **Server Response**: Not all videos will have high-quality URLs available

### Debug Information Missing

1. Ensure you're running a debug build (not release)
2. Check that `kDebugMode` is true
3. Review console output for error messages

### Quality Still Restricted

1. The server may not return high-quality URLs for certain content
2. Some content genuinely requires VIP access and won't have accessible URLs
3. Check if the video itself has high-quality versions available

## License and Attribution

This implementation references the approach from BiliRoamingX but does not copy code verbatim. The original concept and implementation patterns are attributed to the BiliRoamingX project maintainers.

## Support

For issues, questions, or contributions, please refer to the main repository's issue tracker.
