# UniandesSport-Flutter

## Technical Documentation

- Auth/Profile/Firebase integration:
	- [AUTH_PROFILE_FIREBASE.md](AUTH_PROFILE_FIREBASE.md)

## Smart Challenges (Steps + Real-time Match Notifications)

### 1) Step sensor tracking in Retos

The app now supports two challenge progress modes:

- `manual`: users update progress with `-5%` / `+5%` buttons.
- `steps`: users sync progress from the device step sensor.

Where implemented:

- `lib/core/services/step_sensor_service.dart`
	- Wraps the `pedometer` plugin.
	- Exposes latest total steps and a safe `getCurrentTotalSteps()` API.
- `lib/features/home/presentation/pages/retos_page.dart`
	- Challenge creation now evaluates if step tracking is needed.
	- Running challenges default to sensor-based tracking.
	- Joined users can press `Sync steps` to update progress transactionally.
	- First sync now calibrates the sensor baseline and shows a clear message.
	- Runtime permission checks are requested before reading steps.

Firestore fields used in `challenges/{challengeId}`:

- `trackingMode`: `manual | steps`
- `stepGoal`: integer goal for step-based challenges
- `stepProgressByUser.{uid}`: accumulated credited steps for user in that challenge
- `stepSensorBaselineByUser.{uid}`: last sensor total synced to compute safe deltas
- `progressByUser.{uid}`: normalized progress in `[0,1]`

### 2) Smart feature: real-time notification on challenge creation

Implemented in Firebase Functions:

- `functions/index.js` -> `exports.onChallengeCreated`

Behavior:

1. Trigger runs when a new document is created in `challenges/{challengeId}`.
2. It scores candidate users using:
	 - main sport match,
	 - inferred preference for challenge sport,
	 - compatibility with step tracking mode.
3. It only notifies if score passes threshold (`minScore = 0.7`).
4. It applies anti-spam cooldown per user (`cooldownHours = 8`).
5. If FCM tokens exist, sends push notification; otherwise leaves queued record.

Notification audit collection:

- `user_challenge_notifications/{challengeId}_{uid}`

Per-user cooldown marker:

- `users/{uid}.smartFeatureLastChallengeNotificationAt`

### 3) Platform permissions

- Android: `ACTIVITY_RECOGNITION` in `android/app/src/main/AndroidManifest.xml`
- iOS: `NSMotionUsageDescription` in `ios/Runner/Info.plist`

### 4) Dependency added

- `pedometer` in `pubspec.yaml`
- `permission_handler` in `pubspec.yaml`

### 6) Challenge ratings and reviews (stars + comments + image + voice)

Users can now review a challenge when they finish it (100% progress, or when the challenge is already over and they participated).

Where implemented:

- `lib/features/home/presentation/dialogs/challenge_review_dialog.dart`
	- Star rating (1-5).
	- Review text with validation limits.
	- Optional image attachment (camera/gallery) uploaded to Firebase Storage.
	- Voice dictation using `speech_to_text`.
- `lib/features/home/presentation/pages/retos_page.dart`
	- Shows rating summary directly on challenge cards.
	- Details sheet shows stars, counts, and latest reviews (with images when present).
	- Shows CTA to rate/review when challenge is completed for the current user.
- `lib/features/home/domain/recommendation/challenge_recommendation_engine.dart`
	- Recommendation score now includes challenge star rating quality.
	- Added `topRatedChallenges(...)` ranking for a dedicated best-challenges section.

Top-rated section behavior:

- In Retos, a new `Top rated challenges` strip appears before the normal challenge list.
- Ranking considers:
	- average stars (`ratingAverage`),
	- confidence by number of reviews (`ratingCount`).

Firestore schema additions in `challenges/{challengeId}`:

- `ratingAverage`: number (0-5)
- `ratingCount`: number
- `reviewsCount`: number

Reviews are stored in:

- `challenges/{challengeId}/reviews/{uid}`
  - `rating`, `comment`, `imageUrl?`, `userName`, `updatedAt`, `createdAt`

### 5) FCM token sync (end-to-end push readiness)

The app now persists Firebase Cloud Messaging tokens in user profiles so backend
smart notifications can target real devices.

Where implemented:

- `lib/core/services/notification_service.dart`
	- Requests remote notification permissions.
	- Gets current FCM token and saves it in `users/{uid}`.
	- Listens to token refresh and updates Firestore automatically.
	- Handles foreground remote messages by showing a local notification.
	- Handles notification-open events from background/terminated states.

Firestore fields written in `users/{uid}`:

- `fcmToken` (latest token)
- `notificationToken` (compatibility key for existing backend readers)
- `fcmTokens` (array for multi-device support)