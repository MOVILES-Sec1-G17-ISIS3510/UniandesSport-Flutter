# Profile Availability Smart Feature

## Overview
This feature allows users to record a voice note describing their free time.
The app sends the recorded audio to Gemini (`gemini-1.5-flash`) and stores the
extracted schedule blocks in Firestore under:

- `users/{uid}.free_time_slots` (array of maps)

## Architecture
- `lib/features/home/presentation/widgets/profile_availability_widget.dart`
  - UI button to start/stop recording
  - Loading state while Gemini processes audio
  - Firestore update after extraction
- `lib/features/home/data/services/gemini_availability_service.dart`
  - Sends audio bytes as `DataPart`
  - Uses `GenerationConfig` with JSON mime type and low temperature
  - Parses response into `List<TimeSlot>`
- `lib/features/home/domain/models/time_slot.dart`
  - Data model with `fromJson` and `toJson`

## Dependencies
- `record`
- `google_generative_ai`
- `cloud_firestore`

## Notes
- API key is hardcoded by request and should be moved to secure environment
  variables before production.
- Android microphone permission already exists in this project.
- iOS microphone usage description already exists in `Info.plist`.

