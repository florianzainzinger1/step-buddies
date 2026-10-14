# Architecture

This document describes how Step Buddies is structured and how the main data flows work.

## Layers

| Layer | Location | Responsibility |
| --- | --- | --- |
| UI | `lib/screens/`, `lib/widgets/` | Screens, reusable components, animations |
| Theme | `lib/theme/` | Time-of-day palettes and `ThemeService` (`ChangeNotifier`) |
| Services | `lib/services/` | Business logic and all Firebase access |
| Models | `lib/models/` | `Challenge`, `ChallengeTeam`, `Achievement` definitions |
| Strings | `lib/l10n/app_strings.dart` | Centralized UI strings (German) |

## Services

Most services are singletons with a private constructor and a static `instance`:

| Service | Purpose |
| --- | --- |
| `AuthService` | Google Sign-In (google_sign_in 7.x) exchanged for a Firebase credential; sign-out |
| `FirestoreService` | Daily step upserts, today's steps for a set of users, user lookups |
| `StepsService` | Reads the pedometer sensor and derives today's steps (instantiated per screen, not a singleton) |
| `BackgroundSyncService` | Registers and cancels the periodic WorkManager task |
| `FriendsService` | User search, friend requests, suggestions, friend lists |
| `GroupsService` | Create, join by code, leave, watch groups |
| `ChallengesService` | Create and update challenges, compute team scores |
| `AchievementsService` | Achievement definitions, evaluation and unlock notifications |
| `DeepLinkService` | Handles `stepbuddies://profile?id=...` and `stepbuddies://group?id=...` links via a global navigator key |

`ThemeService` is provided at the root with `ChangeNotifierProvider`. It checks the current time periodically and switches between four periods: dawn (05:00-08:00), day (08:00-17:00), dusk (17:00-20:00) and night (20:00-05:00). Users can override this with an always-light or always-dark mode.

## App start and routing

`main.dart` initializes Firebase with `DefaultFirebaseOptions.currentPlatform`, sets up deep links, and then routes based on auth state:

1. No Firebase user: `SignInScreen`.
2. Signed in without a `users/{uid}` document: `OnboardingScreen` (username, daily goal, leaderboard visibility).
3. Signed in with a profile: `HomeScreen`, which starts background sync and loads today's steps.

## Step counting

The Android step counter reports cumulative steps since the last device boot. `StepsService` turns this into a per-day value using three `SharedPreferences` keys:

- `steps_last_date`: the day the current baseline belongs to
- `steps_at_day_start`: the sensor value at the baseline
- `steps_last_known`: the most recent sensor value

On each read:

1. Request the activity-recognition permission; return `permissionDenied` if it is not granted.
2. Read one value from the pedometer stream, with a timeout; return `sensorUnavailable` on error or timeout.
3. If this is the first run, the date has changed, or the sensor value is lower than `steps_last_known` (reboot), store a new baseline and report 0.
4. Otherwise report `current - steps_at_day_start` and update `steps_last_known`.

A limitation of this approach is that steps taken between midnight and the first read of the day, or between a reboot and the next read, are not counted.

## Background sync

`BackgroundSyncService.initialize(userId)` stores the user ID in `SharedPreferences` and registers a periodic WorkManager task (15 minutes, the Android minimum, with a network constraint). The top-level `callbackDispatcher` runs in a background isolate and:

1. Calls `Firebase.initializeApp()` (in the background isolate this relies on the native Firebase configuration from `google-services.json`).
2. Reads the user ID; skips if nobody is signed in.
3. Reads the sensor and applies the same baseline logic as `StepsService`, using the same preference keys.
4. Upserts `dailySteps/{userId}_{YYYY-MM-DD}` with `source: background_sync`.

## Firestore data model

| Collection | Document ID | Key fields |
| --- | --- | --- |
| `users` | UID | `username`, `usernameLowercase`, `displayName`, `friendIds`, `dailyStepGoal`, `showOnGlobalLeaderboard` |
| `dailySteps` | `{userId}_{YYYY-MM-DD}` | `userId`, `date` (midnight), `steps`, `updatedAt` |
| `friendRequests` | auto | `fromUserId`, `toUserId`, `status` |
| `groups` | auto | `name`, `memberIds`, `joinCode` |
| `challenges` | auto | `title`, `adminId`, `startDate`, `durationDays`, `status`, `teams[]`, `participantIds` |
| `userAchievements` | UID | Unlocked achievements |
| `userStats` | UID | Aggregated all-time stats |

Notes:

- `usernameLowercase` enables case-insensitive prefix search with a `>= q` / `<= q + ''` range query.
- `participantIds` on a challenge is a denormalized list so "my challenges" can be queried with `array-contains`.
- Friend acceptance and group joins run in Firestore transactions.

## Challenges

A challenge has teams, each with member IDs. Status moves from `pending` to `active` to `completed`. The end date is `startDate + durationDays` (exclusive). `ChallengesService.getChallengeScores` sums each member's `dailySteps` with `date >= startMidnight` and `date < endMidnight` and aggregates per team. The UI shows the teams as a race track.
