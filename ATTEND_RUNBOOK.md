# Attend build-out (slice 1) — apply & build

Turns the Attend tab from a mock into a real streaming directory with in-app playback.

## What changed
- **Migration `0018_church_streaming.sql`:** adds streaming fields to `churches`
  (`platform`, `youtube_channel_id`, `hls_url`, `watch_url`, `thumbnail_url`,
  `denomination`) and seeds a starter directory of 6 real churches + service rows
  (Life.Church, Elevation, Transformation Church, The Potter's House, Bethel,
  Saddleback). Also makes `ChurchDTO.distanceMiles` optional so a null distance
  can't break decoding.
- **Real video player** (`Features/Attend/StreamPlayer.swift`): a full-screen
  `WatchView` that embeds YouTube via the official iframe live embed
  (ToS-compliant — never raw HLS extraction), plays direct HLS via `AVPlayer`,
  and (in `ServiceDetailView`) links out for anything else.
- **`ServiceDetailView`:** "Watch Live" now actually opens the stream (in-app for
  YouTube/HLS, link-out to the church's `/live` page otherwise); header shows a
  real thumbnail when present.
- **`AttendView`:** "Live Now" hero + rows come from the real `fetchLiveServices`
  feed (was `MockData.liveNow`); live vs. starting-soon vs. scheduled are now
  separated correctly.

## Apply & build
1. Apply the migration (has seed data; SQL editor is fine):
   ```
   cd ~/Projects/Crossed*/ && pbcopy < supabase/migrations/0018_church_streaming.sql   # paste → Run
   ```
2. Regenerate + build (new file `StreamPlayer.swift`):
   ```
   cd ~/Projects/Crossed*/ && xcodegen generate
   ```
   then build `CrossedOut.xcodeproj` in Xcode.

## Smoke test
- **Attend tab** shows "Live Now" with Life.Church + Elevation (seeded `is_live`),
  and scheduled churches under Starting Soon / Tomorrow.
- Tap a church → watch page with real name/city/style → **Watch Live**:
  - Life.Church / Elevation (have channel IDs) → opens the **in-app YouTube player**.
    Note: the embed reflects *real* YouTube live status — if the channel isn't
    actually live at that moment, YouTube shows "offline/upcoming" inside the
    player. That's correct behavior, not a bug.
  - Others (no channel ID) → **link out** to the church's YouTube `/live` page.
- **Save Church** persists (check again after reopening).

## Next slices (not in this one)
- Real thumbnails (seed `thumbnail_url`), denomination/style **filters**, "near
  you", and richer church profiles (statement of faith, parking, kids, etc.).
- Replace the placeholder "Set a Reminder" with real APNs scheduling.
- Consider YouTubePlayerKit (SPM) later for nicer native controls than the iframe.
