# PR: Implement Trial/VIP Quality Unlock Feature

## Summary

This PR implements an opt-in feature to unlock trial and VIP quality streams in PiliPlus, referencing the implementation approach from BiliRoamingX. The feature allows non-VIP users to access high-quality streams when the server returns accessible URLs.

## Implementation Details

### Reference Projects
This implementation references (but does not copy) code from BiliRoamingX:
- [VideoQualityPatch.java](https://github.com/BiliRoamingX/BiliRoamingX/blob/ae58109f3acdd53ec2d2b3fb439c2a2ef1886221/integrations/app/src/main/java/app/revanced/bilibili/patches/VideoQualityPatch.java)
- [TrialQualityPatch.java](https://github.com/BiliRoamingX/BiliRoamingX/blob/main/integrations/app/src/main/java/app/revanced/bilibili/patches/TrialQualityPatch.java#L22-L44)
- [PlayURLPlayViewUGC.kt](https://github.com/BiliRoamingX/BiliRoamingX/blob/main/integrations/app/src/main/java/app/revanced/bilibili/patches/protobuf/hooks/PlayURLPlayViewUGC.kt#L58-L60)
- [BangumiPlayUrlHook.kt](https://github.com/BiliRoamingX/BiliRoamingX/blob/main/integrations/app/src/main/java/app/revanced/bilibili/patches/protobuf/BangumiPlayUrlHook.kt#L110-L120)

### Key Changes

#### 1. Settings Integration (3 files modified)

**`lib/utils/storage_key.dart`**
- Added `enableTrialQuality` setting key

**`lib/utils/storage_pref.dart`**
- Added `enableTrialQuality` getter (default: `false`)

**`lib/pages/setting/models/video_settings.dart`**
- Added settings switch with title "解锁试用/会员画质"
- Implemented risk warning dialog when enabling
- Default state: OFF (disabled)

#### 2. Core Unlock Logic (1 file modified)

**`lib/http/video.dart`**
- Added `_makeVipFreePlayUrlModel()` function
  - Processes PlayUrlModel after successful parsing
  - Scans dash video/audio streams
  - Scans durl (legacy format) streams
  - Logs available streams for debugging
- Added `_hasPlayableUrls()` helper function
- Integrated unlock call in `videoUrl()` method
- Added comprehensive debug logging

#### 3. Documentation (1 file added)

**`docs/trial_quality_unlock_feature.md`**
- Complete feature documentation
- Manual testing steps
- Sample response examples
- Risk warnings and compliance notes
- Troubleshooting guide

### How It Works

1. **Request Phase** (already present):
   - `fnval=4048`: Requests all video formats
   - `fourk=1`: Requests 4K support
   - `try_look=1`: Requests trial access

2. **Response Processing** (new):
   - When enabled via settings, processes PlayUrlModel response
   - Scans all video/audio streams for available URLs
   - Logs stream details in debug mode
   - Allows player/downloader to use all accessible streams

3. **User Interface**:
   - Settings toggle with risk acknowledgment dialog
   - Debug logs show stream availability
   - No visual changes when disabled

## Testing

### Manual Test Steps

See `docs/trial_quality_unlock_feature.md` for detailed testing instructions.

**Quick Test:**
1. Use non-VIP account
2. Enable feature in Settings → Audio/Video Settings → "解锁试用/会员画质"
3. Open any video and check console logs for `[UnlockQuality]` messages
4. Verify quality options and playback

### Sample Debug Output

```
[UnlockQuality] Video stream available: quality=116, codec=avc1.640032, url=https://...
[UnlockQuality] Audio stream available: quality=高音质, url=https://...
```

## Risk Warnings and Compliance

### ⚠️ Important

1. **Educational Purpose**: For technical learning and research only
2. **No Bypass**: Does not decrypt or bypass DRM - only uses server-provided URLs
3. **Default OFF**: Disabled by default, requires explicit user opt-in
4. **User Risk**: Users acknowledge risks via dialog when enabling
5. **ToS Compliance**: May violate Bilibili ToS - use responsibly
6. **No Warranty**: Provided as-is for educational purposes

### Compliance Notes

- This feature does NOT:
  - Crack encrypted content
  - Bypass DRM protection
  - Modify server responses
  - Use unauthorized APIs
  
- This feature DOES:
  - Process client-side response data
  - Allow access to streams where URLs are already provided
  - Require explicit user consent
  - Include comprehensive warnings

## Verification Checklist

- [x] Feature is OFF by default
- [x] User must explicitly enable with acknowledgment
- [x] Risk warning dialog implemented
- [x] Debug logging added
- [x] No changes to network requests (fnval/fourk/try_look already present)
- [x] Documentation completed
- [x] Code references BiliRoamingX approach (not copied)
- [x] Graceful error handling
- [x] No impact when disabled

## Technical Notes

### Architecture
- Non-intrusive: Only processes data, doesn't modify requests
- Conditional: Only executes when enabled
- Defensive: Error handling prevents disruption
- Observable: Debug logging for troubleshooting

### Files Modified
- `lib/utils/storage_key.dart` (1 line added)
- `lib/utils/storage_pref.dart` (3 lines added)
- `lib/pages/setting/models/video_settings.dart` (~35 lines added)
- `lib/http/video.dart` (~85 lines added)

### Files Added
- `docs/trial_quality_unlock_feature.md` (comprehensive documentation)

## Future Enhancements (Not in this PR)

Potential improvements for future PRs:
1. gRPC/protobuf response handling with `StreamInfo.needVip`/`vipFree` fields
2. UI indicator showing unlocked streams
3. Statistics tracking
4. Per-video unlock status display

## Attribution

Implementation approach referenced from BiliRoamingX project. Original concept credit goes to BiliRoamingX maintainers.

## Related Issues

Closes #7
