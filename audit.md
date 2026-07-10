# FixBuddy Codebase Audit

## Section A — What Is Fully Working
- **Core Services (Data Layer)**: The entire `lib/services/` folder (`worker_service.dart`, `booking_service.dart`, `category_service.dart`, `chat_service.dart`, `review_service.dart`, `profile_service.dart`) is fully connected to Supabase using live SQL/RPC queries.
- **Worker Reviews (`lib/screens/worker/worker_reviews_screen.dart`)**: Correctly fetches reviews from `ReviewService` and dynamically aggregates the average rating and star distribution using real data.
- **Chat System (`lib/screens/user/chat_screen.dart`)**: Dynamically fetches chat details and uses `streamMessages` to show real-time messages directly connected to Supabase streams.
- **User Home Screen (`lib/screens/user/user_home_screen.dart`)**: Dynamically loads active service categories and areas via `CategoryService` and `AreaService`.
- **Authentication Flow (`lib/screens/auth/`)**: Correctly handles login/registration, fetches profile roles dynamically, and redirects users to the correct shell using `app_router.dart`.

## Section B — What Is Broken or Partially Working
- **Worker Profile Form Type Error (`lib/screens/worker/worker_profile_manage_screen.dart`)**: There is a compilation error on the Category `DropdownButtonFormField`. `w.categories.first.categoryId` is inferred as `Object?` and fails assignment to `String?` (Line 126). 
- **Worker Model Types (`lib/models/worker_model.dart`)**: The `categories` and `serviceAreas` properties likely lack strict typing (e.g., they might be parsed as `List<dynamic>`), causing the type mismatch in the profile manage screen.
- **Area Dropdown Initial Value (`lib/screens/worker/worker_profile_manage_screen.dart`)**: The dropdown tries to manage an array `_selectedAreaIds` but has its `initialValue` set to `null` while the array state might not map perfectly to the UI, causing potential initialization bugs when a worker already has selected areas.

## Section C — What Is Hardcoded or Static
- **Payment Methods (`lib/screens/user/booking_screen.dart`)**: The payment methods ("Cash", "bKash", "Nagad", "Rocket"), including their icons and descriptions, are completely hardcoded into the UI.
- **Time Slots (`lib/screens/user/booking_screen.dart`)**: The labels ('Morning', 'Afternoon', 'Evening') and their exact start times (9am, 2pm, 5pm) are hardcoded in `_getPeriodLabel` and `_getTimeForPeriod` instead of loading from the backend.
- **Booking Status Tabs (`lib/screens/worker/worker_booking_history_screen.dart`)**: The filter tabs (`['Pending', 'Confirmed', 'Completed', 'Cancelled', 'Declined']`) are statically defined.
- **Chat Typing Indicator (`lib/screens/user/chat_screen.dart`)**: The pulsing `_TypingDots` animation string is hardcoded logic rather than using an asset or dynamic widget approach.

## Section D — Navigation Gaps
- **Export Reports Button Trigger (`lib/screens/admin/reports_screen.dart`)**: The `OutlinedButton` inside the `PopupMenuButton` has an empty callback `onPressed: () {}` (Line 256). It relies solely on the popup menu behavior, which can cause accessibility and routing overlap issues.
- **Back Navigation Fallbacks**: Various screens use `context.go()` for back navigation instead of `context.pop()`. This means if a user navigates deeply and presses the back button, they may be forced back to a root shell instead of the previous screen.
