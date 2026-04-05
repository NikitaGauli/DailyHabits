# DailyHabits Application — Comprehensive Unit Test Cases

**Project:** DailyHabits - Habit Tracking & Community Platform  
**Version:** 2.0.0  
**Date:** March 2026  
**Classification:** Production-Level QA Documentation  

---

## Table of Contents

1. [Test Overview & Guidelines](#test-overview--guidelines)
2. [Module 1: User Registration & Login](#module-1-user-registration--login)
3. [Module 2: Profile Management](#module-2-profile-management)
4. [Module 3: Habit Creation & Management](#module-3-habit-creation--management)
5. [Module 4: Habit Tracking & Streak System](#module-4-habit-tracking--streak-system)
6. [Module 5: Dashboard & Analytics](#module-5-dashboard--analytics)
7. [Module 6: Notifications & Reminders](#module-6-notifications--reminders)
8. [Module 7: Gamification (XP, Badges, Challenges)](#module-7-gamification-xp-badges-challenges)
9. [Module 8: Community & Leaderboard](#module-8-community--leaderboard)
10. [Appendix: Test Data Sets](#appendix-test-data-sets)

---

## Test Overview & Guidelines

### Test Case Format

Each test case includes the following structure:

| Field | Description |
|-------|-------------|
| **Test Case ID** | Unique identifier (MODULE_TC_001) |
| **Module Name** | Feature module being tested |
| **Component** | Backend (Django) or Frontend (Flutter) |
| **Test Scenario** | Descriptive name of the test |
| **Test Steps** | Sequential actions to execute |
| **Test Data** | Input values, parameters, or fixtures |
| **Expected Result** | Anticipated outcome or response |
| **Actual Result** | Result after execution (documented during testing) |
| **Status** | PASS / FAIL / PENDING |

### Testing Scope

- **Positive Tests:** Valid inputs, expected behaviors  
- **Negative Tests:** Invalid inputs, error conditions  
- **Edge Cases:** Boundary values, unusual scenarios  
- **Integration Points:** Cross-module dependencies  

### Test Coverage

| Module | Backend Tests | Frontend Tests | Total |
|--------|---------------|----------------|-------|
| User Registration & Login | 15 | 12 | 27 |
| Profile Management | 12 | 10 | 22 |
| Habit Creation & Management | 18 | 14 | 32 |
| Habit Tracking & Streak | 12 | 10 | 22 |
| Dashboard & Analytics | 10 | 8 | 18 |
| Notifications & Reminders | 10 | 8 | 18 |
| Gamification | 12 | 8 | 20 |
| Community & Leaderboard | 12 | 8 | 20 |
| **TOTAL** | **101** | **78** | **179** |

---

---

# MODULE 1: USER REGISTRATION & LOGIN

## 1.1 Backend Tests

### Test Case: AUTH_BE_TC_001

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_001 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Valid user registration with complete credentials |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Launch POST `/api/auth/register/`<br/>2. Provide valid email, name, password, password confirmation<br/>3. Send request<br/>4. Verify user is created in database<br/>5. Verify JWT tokens are returned |
| **Test Data** | `email`: "john.doe@example.com"<br/>`name`: "John Doe"<br/>`password`: "SecurePass123!@#"<br/>`password2`: "SecurePass123!@#" |
| **Expected Result** | HTTP 201 CREATED<br/>Response: `{ success: true, user: {...}, token: "jwt_token", refresh: "refresh_token" }`<br/>User record in database with hashed password<br/>Auth provider set to "email" |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Verify password hashing algorithm (Django default) |

---

### Test Case: AUTH_BE_TC_002

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_002 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Registration with duplicate email |
| **Priority** | P0 - Critical |
| **Type** | Negative Test |
| **Test Steps** | 1. Register user with email "user@example.com"<br/>2. Attempt to register again with same email<br/>3. Verify error response<br/>4. Check database has only one user record |
| **Test Data** | First registration: email "user@example.com"<br/>Second registration: email "user@example.com" |
| **Expected Result** | HTTP 400 BAD REQUEST<br/>Error message: "Email already registered"<br/>Only one user in database |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Email field has unique=True constraint |

---

### Test Case: AUTH_BE_TC_003

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_003 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Registration with mismatched passwords |
| **Priority** | P0 - Critical |
| **Type** | Negative Test |
| **Test Steps** | 1. POST to `/api/auth/register/`<br/>2. Provide password: "SecurePass123!@#"<br/>3. Provide password2: "DifferentPass456!@#"<br/>4. Send request |
| **Test Data** | `email`: "test@example.com"<br/>`name`: "Test User"<br/>`password`: "SecurePass123!@#"<br/>`password2`: "DifferentPass456!@#" |
| **Expected Result** | HTTP 400 BAD REQUEST<br/>Error: "Password fields didn't match."<br/>No user created in database |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Cross-field validation in RegisterSerializer |

---

### Test Case: AUTH_BE_TC_004

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_004 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Registration with weak password |
| **Priority** | P0 - Critical |
| **Type** | Negative Test |
| **Test Steps** | 1. POST to `/api/auth/register/`<br/>2. Provide weak password (e.g., "123")<br/>3. Send request<br/>4. Verify validation error |
| **Test Data** | `password`: "123"<br/>`password2`: "123" |
| **Expected Result** | HTTP 400 BAD REQUEST<br/>Error mentioning password strength requirements<br/>No user created |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Django validate_password validates minimum length and complexity |

---

### Test Case: AUTH_BE_TC_005

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_005 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Registration with invalid email format |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. POST to `/api/auth/register/`<br/>2. Provide invalid email (e.g., "notanemail")<br/>3. Send request |
| **Test Data** | `email`: "notanemail"<br/>`name`: "Test User"<br/>`password`: "SecurePass123!@#"<br/>`password2`: "SecurePass123!@#" |
| **Expected Result** | HTTP 400 BAD REQUEST<br/>Error: "Enter a valid email address"<br/>No user created |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | EmailField validation |

---

### Test Case: AUTH_BE_TC_006

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_006 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Valid user login with email and password |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Create a user with known credentials<br/>2. POST to `/api/auth/login/`<br/>3. Provide email and password<br/>4. Verify JWT tokens are returned<br/>5. Verify token is valid for authenticated requests |
| **Test Data** | `email`: "john.doe@example.com"<br/>`password`: "SecurePass123!@#" |
| **Expected Result** | HTTP 200 OK<br/>Response: `{ success: true, token: "jwt_token", refresh: "refresh_token", user: {...} }`<br/>Token is valid for 24 hours |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Default JWT expiration: 24 hours |

---

### Test Case: AUTH_BE_TC_007

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_007 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Login with incorrect password |
| **Priority** | P0 - Critical |
| **Type** | Negative Test |
| **Test Steps** | 1. Create a user with password "CorrectPass123!@#"<br/>2. POST to `/api/auth/login/`<br/>3. Provide correct email but wrong password "WrongPass456!@#"<br/>4. Verify error response |
| **Test Data** | `email`: "user@example.com"<br/>`password`: "WrongPass456!@#" |
| **Expected Result** | HTTP 401 UNAUTHORIZED<br/>Error: "Invalid email or password"<br/>No token returned |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Security: Generic error message (not revealing if email exists) |

---

### Test Case: AUTH_BE_TC_008

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_008 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Login with non-existent email |
| **Priority** | P0 - Critical |
| **Type** | Negative Test |
| **Test Steps** | 1. POST to `/api/auth/login/`<br/>2. Provide non-existent email "nonexistent@example.com"<br/>3. Provide any password<br/>4. Verify error response |
| **Test Data** | `email`: "nonexistent@example.com"<br/>`password`: "SomePass123!@#" |
| **Expected Result** | HTTP 401 UNAUTHORIZED<br/>Error: "Invalid email or password" |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Security: Generic error message |

---

### Test Case: AUTH_BE_TC_009

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_009 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Google OAuth registration - new user |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. POST to `/api/auth/google/`<br/>2. Provide valid Google token<br/>3. Verify user is created with google_id and auth_provider='google'<br/>4. Verify JWT tokens are returned |
| **Test Data** | `token`: "valid_google_token"<br/>Google user data: email, name, picture URL |
| **Expected Result** | HTTP 201 CREATED<br/>User created with `auth_provider='google'`<br/>JWT tokens returned<br/>No password hash stored |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Requires Google API verification |

---

### Test Case: AUTH_BE_TC_010

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_010 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Google OAuth login - existing user |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Create user with google_id<br/>2. POST to `/api/auth/google/` with same Google token<br/>3. Verify user is NOT duplicated<br/>4. Verify JWT tokens are returned |
| **Test Data** | Existing user with `google_id='123456'` |
| **Expected Result** | HTTP 200 OK<br/>JWT tokens returned<br/>No new user created (same user_id) |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Idempotent operation |

---

### Test Case: AUTH_BE_TC_011

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_011 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Logout functionality |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Login user and obtain token<br/>2. POST to `/api/auth/logout/` with token<br/>3. Verify token is blacklisted<br/>4. Attempt to use token for authenticated request<br/>5. Verify access is denied |
| **Test Data** | Valid JWT token from login |
| **Expected Result** | HTTP 200 OK on logout<br/>Subsequent requests with token: HTTP 401 UNAUTHORIZED |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Token blacklisting mechanism |

---

### Test Case: AUTH_BE_TC_012

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_012 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Refresh JWT token |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Obtain refresh token from login<br/>2. POST to `/api/auth/token/refresh/`<br/>3. Provide refresh token<br/>4. Verify new access token is returned |
| **Test Data** | Valid refresh token |
| **Expected Result** | HTTP 200 OK<br/>New access token returned<br/>Token is valid for subsequent requests |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Refresh token remains valid across refreshes |

---

### Test Case: AUTH_BE_TC_013

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_013 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Access protected endpoint without token |
| **Priority** | P0 - Critical |
| **Type** | Negative Test |
| **Test Steps** | 1. GET `/api/profile/` without Authorization header<br/>2. Verify access is denied |
| **Test Data** | No token in header |
| **Expected Result** | HTTP 401 UNAUTHORIZED<br/>Error: "Authentication credentials were not provided." |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | IsAuthenticated permission class |

---

### Test Case: AUTH_BE_TC_014

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_014 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Access protected endpoint with invalid token |
| **Priority** | P0 - Critical |
| **Type** | Negative Test |
| **Test Steps** | 1. GET `/api/profile/` with malformed token<br/>2. Verify access is denied |
| **Test Data** | `Authorization: Bearer invalid.token.here` |
| **Expected Result** | HTTP 401 UNAUTHORIZED<br/>Error: "Token is invalid or expired" |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | JWT validation failure |

---

### Test Case: AUTH_BE_TC_015

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_BE_TC_015 |
| **Module Name** | User Registration & Login |
| **Component** | Backend (Django) |
| **Test Scenario** | Login activity logging |
| **Priority** | P2 - Medium |
| **Type** | Positive Test |
| **Test Steps** | 1. Login with user credentials<br/>2. Verify LoginActivity record is created in database<br/>3. Check timestamp and IP address are recorded |
| **Test Data** | User login with IP "192.168.1.1" |
| **Expected Result** | LoginActivity record created<br/>Fields: user, timestamp, ip_address, user_agent<br/>Timestamp matches request time |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Used for login history endpoint |

---

## 1.2 Frontend Tests

### Test Case: AUTH_FE_TC_001

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_FE_TC_001 |
| **Module Name** | User Registration & Login |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Registration form validation - valid input |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Open registration screen<br/>2. Enter valid email, name, password, password confirmation<br/>3. Verify form accepts input<br/>4. Verify submit button is enabled<br/>5. Tap submit button |
| **Test Data** | `email`: "flutter@test.com"<br/>`name`: "Flutter Tester"<br/>`password`: "TestPass123!@#"<br/>`passwordConfirm`: "TestPass123!@#" |
| **Expected Result** | Form accepts input<br/>Submit button enabled<br/>Loading indicator shows<br/>Redirected to home screen (success)<br/>User can access authenticated endpoints |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test with mocked API |

---

### Test Case: AUTH_FE_TC_002

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_FE_TC_002 |
| **Module Name** | User Registration & Login |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Registration form validation - email field |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Open registration screen<br/>2. Enter invalid email (e.g., "notanemail")<br/>3. Verify error message appears under email field<br/>4. Verify submit button is disabled |
| **Test Data** | `email`: "notanemail"<br/>`name`: "Test"<br/>`password`: "Pass123!@#"<br/>`passwordConfirm`: "Pass123!@#" |
| **Expected Result** | Error message: "Please enter a valid email"<br/>Submit button disabled<br/>Red border on email field |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Real-time validation on field blur |

---

### Test Case: AUTH_FE_TC_003

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_FE_TC_003 |
| **Module Name** | User Registration & Login |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Registration form validation - password mismatch |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Open registration screen<br/>2. Enter password and different confirmation<br/>3. Verify error message appears<br/>4. Verify submit button is disabled |
| **Test Data** | `password`: "TestPass123!@#"<br/>`passwordConfirm`: "DifferentPass456!@#" |
| **Expected Result** | Error message: "Passwords don't match"<br/>Submit button disabled<br/>Error shown at confirmation field |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Cross-field validation |

---

### Test Case: AUTH_FE_TC_004

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_FE_TC_004 |
| **Module Name** | User Registration & Login |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Registration API error handling - duplicate email |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Register user successfully<br/>2. On same physical device, register again with duplicate email<br/>3. Verify error dialog appears<br/>4. Verify user remains on registration screen<br/>5. Verify form data is retained |
| **Test Data** | Email: "duplicate@test.com" |
| **Expected Result** | Error dialog: "This email is already registered"<br/>User can retry with different email<br/>Existing user not affected |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test error handling from 400 response |

---

### Test Case: AUTH_FE_TC_005

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_FE_TC_005 |
| **Module Name** | User Registration & Login |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Registration network error handling |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Disable network connectivity<br/>2. Open registration and fill form<br/>3. Tap submit button<br/>4. Verify error message appears<br/>5. Verify retry option is available<br/>6. Enable network and retry |
| **Test Data** | Valid form data |
| **Expected Result** | Error message: "Network error. Please check your connection."<br/>Retry button available<br/>Upon retry with network enabled, registration succeeds |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test network error resilience |

---

### Test Case: AUTH_FE_TC_006

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_FE_TC_006 |
| **Module Name** | User Registration & Login |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Login form with valid credentials |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Open login screen<br/>2. Enter registered email<br/>3. Enter correct password<br/>4. Tap login button<br/>5. Verify tokens are stored locally<br/>6. Verify redirect to home screen |
| **Test Data** | `email`: "user@test.com"<br/>`password`: "SecurePass123!@#" |
| **Expected Result** | Loading indicator shows<br/>Tokens stored in secure storage<br/>Redirect to home screen<br/>User profile visible<br/>Authenticated requests work |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test token persistence and secure storage |

---

### Test Case: AUTH_FE_TC_007

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_FE_TC_007 |
| **Module Name** | User Registration & Login |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Login with incorrect password |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Open login screen<br/>2. Enter valid email<br/>3. Enter wrong password<br/>4. Tap login button<br/>5. Verify error message<br/>6. Verify user stays on login screen |
| **Test Data** | `email`: "user@test.com"<br/>`password`: "WrongPass123!@#" |
| **Expected Result** | Error message: "Invalid email or password"<br/>No tokens stored<br/>User remains on login screen<br/>Can retry |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test error handling from 401 response |

---

### Test Case: AUTH_FE_TC_008

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_FE_TC_008 |
| **Module Name** | User Registration & Login |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Google Sign In button functionality |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Open login screen<br/>2. Tap "Sign in with Google" button<br/>3. Verify Google sign-in popup appears<br/>4. Complete Google authentication<br/>5. Verify tokens are obtained<br/>6. Verify redirect to home screen |
| **Test Data** | Google test account credentials |
| **Expected Result** | Google sign-in flow initiates<br/>After authentication, tokens obtained<br/>Redirect to home screen<br/>User profile populated from Google data |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Requires Google Sign-In SDK setup |

---

### Test Case: AUTH_FE_TC_009

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_FE_TC_009 |
| **Module Name** | User Registration & Login |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Logout functionality |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Login user successfully<br/>2. Navigate to settings<br/>3. Tap "Logout" button<br/>4. Verify confirmation dialog<br/>5. Confirm logout<br/>6. Verify tokens are cleared from storage<br/>7. Verify redirect to login screen<br/>8. Verify cannot access authenticated screens |
| **Test Data** | Logged-in user session |
| **Expected Result** | Confirmation dialog shows<br/>On confirmation: tokens cleared from device<br/>Redirect to login screen<br/>Protected screens no longer accessible |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test secure token deletion |

---

### Test Case: AUTH_FE_TC_010

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_FE_TC_010 |
| **Module Name** | User Registration & Login |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Token refresh on expired access token |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Login and obtain tokens<br/>2. Simulate expired access token (manipulate local storage)<br/>3. Make API request that requires authentication<br/>4. Verify refresh token is used to obtain new access token<br/>5. Verify request is retried with new token<br/>6. Verify user doesn't see logout event |
| **Test Data** | Expired JWT access token + valid refresh token |
| **Expected Result** | Refresh token used automatically<br/>New access token obtained from backend<br/>Original request succeeds<br/>Seamless token refresh (user unaware) |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test automatic token refresh mechanism |

---

### Test Case: AUTH_FE_TC_011

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_FE_TC_011 |
| **Module Name** | User Registration & Login |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Password visibility toggle |
| **Priority** | P2 - Medium |
| **Type** | Positive Test |
| **Test Steps** | 1. Open login/registration screen<br/>2. Enter password into password field<br/>3. Verify password is hidden (dots/bullets)<br/>4. Tap eye icon to show password<br/>5. Verify password text is visible<br/>6. Tap eye icon to hide password<br/>7. Verify password is hidden again |
| **Test Data** | `password`: "Secure123!@#" |
| **Expected Result** | Password hidden by default (obscured)<br/>Eye icon toggles visibility<br/>Text shown as asterisks when hidden<br/>Text shown as cleartext when visible |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | UX improvement for password entry |

---

### Test Case: AUTH_FE_TC_012

| Aspect | Details |
|--------|---------|
| **Test Case ID** | AUTH_FE_TC_012 |
| **Module Name** | User Registration & Login |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Auto-login on app restart after successful registration |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Perform successful registration<br/>2. Verify user is on home screen<br/>3. Kill app (force close)<br/>4. Reopen app<br/>5. Verify app skips login screen and shows home screen<br/>6. Verify user profile is restored from token |
| **Test Data** | Newly registered user with valid tokens in secure storage |
| **Expected Result** | Splash screen shown briefly<br/>Home screen displayed (no login required)<br/>User data loaded<br/>Authenticated requests work immediately |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test persistent authentication state |

---

---

# MODULE 2: PROFILE MANAGEMENT

## 2.1 Backend Tests

### Test Case: PROF_BE_TC_001

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_BE_TC_001 |
| **Module Name** | Profile Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Retrieve user profile |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user<br/>2. GET `/api/auth/profile/`<br/>3. Verify all profile fields are returned |
| **Test Data** | Authenticated user with ID=1 |
| **Expected Result** | HTTP 200 OK<br/>Response includes: id, email, name, profile_image, auth_provider, created_at, current_streak, total_habits_completed |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | UserSerializer used for response |

---

### Test Case: PROF_BE_TC_002

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_BE_TC_002 |
| **Module Name** | Profile Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Update user profile - name |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user<br/>2. PATCH `/api/auth/profile/`<br/>3. Update name field<br/>4. Verify updated_at timestamp changes<br/>5. Verify other fields unchanged |
| **Test Data** | `name`: "New Name Updated" |
| **Expected Result** | HTTP 200 OK<br/>Profile updated in database<br/>Name changed to "New Name Updated"<br/>Other fields remain same<br/>updated_at timestamp changed |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Partial update allowed with PATCH |

---

### Test Case: PROF_BE_TC_003

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_BE_TC_003 |
| **Module Name** | Profile Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Update user profile - profile image URL |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user<br/>2. PATCH `/api/auth/profile/`<br/>3. Provide profile_image URL<br/>4. Verify URL is stored<br/>5. Verify image is accessible |
| **Test Data** | `profile_image`: "https://cdn.example.com/profile/user1.jpg" |
| **Expected Result** | HTTP 200 OK<br/>URL stored in database<br/>Field can be updated multiple times<br/>Old image URL is replaced |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | URLField validation |

---

### Test Case: PROF_BE_TC_004

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_BE_TC_004 |
| **Module Name** | Profile Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Update profile with invalid data - malformed image URL |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Authenticate as user<br/>2. PATCH `/api/auth/profile/`<br/>3. Provide invalid URL in profile_image<br/>4. Verify validation error |
| **Test Data** | `profile_image`: "not-a-valid-url" |
| **Expected Result** | HTTP 400 BAD REQUEST<br/>Error: "Enter a valid URL"<br/>Profile not updated |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | URLField validation on update |

---

### Test Case: PROF_BE_TC_005

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_BE_TC_005 |
| **Module Name** | Profile Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Retrieve another user's profile (read-only access) |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user A<br/>2. GET `/api/social/users/{user_b_id}/`<br/>3. Verify only public fields are returned<br/>4. Verify auth_provider is visible for social features |
| **Test Data** | User B with ID=2, email="user2@example.com" |
| **Expected Result** | HTTP 200 OK<br/>Public profile data returned: name, profile_image, created_at, current_streak<br/>Email may or may not be visible (design decision)<br/>Sensitive data not exposed |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Different serializer for public profiles |

---

### Test Case: PROF_BE_TC_006

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_BE_TC_006 |
| **Module Name** | Profile Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Change password - valid current password |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user<br/>2. POST `/api/auth/change-password/`<br/>3. Provide current password and new password<br/>4. Verify password is updated<br/>5. Verify old password no longer works<br/>6. Verify new password works for login |
| **Test Data** | `current_password`: "OldPass123!@#"<br/>`new_password`: "NewPass456!@#"<br/>`new_password2`: "NewPass456!@#" |
| **Expected Result** | HTTP 200  OK<br/>Password updated in database<br/>Old password fails on login<br/>New password works for login<br/>User can continue using app without logout |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | ChangePasswordSerializer validates current password |

---

### Test Case: PROF_BE_TC_007

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_BE_TC_007 |
| **Module Name** | Profile Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Change password - incorrect current password |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Authenticate as user<br/>2. POST `/api/auth/change-password/`<br/>3. Provide wrong current password<br/>4. Verify error and password unchanged |
| **Test Data** | `current_password`: "WrongOldPass123!@#"<br/>`new_password`: "NewPass456!@#" |
| **Expected Result** | HTTP 400 BAD REQUEST<br/>Error: "Current password is incorrect"<br/>Password in database unchanged<br/>Old password still works |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Security validation |

---

### Test Case: PROF_BE_TC_008

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_BE_TC_008 |
| **Module Name** | Profile Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Change password - new passwords don't match |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Authenticate as user<br/>2. POST `/api/auth/change-password/`<br/>3. Provide matching current password but mismatched new passwords<br/>4. Verify error |
| **Test Data** | `current_password`: "CorrectOldPass123!@#"<br/>`new_password`: "NewPass456!@#"<br/>`new_password2`: "DifferentPass789!@#" |
| **Expected Result** | HTTP 400 BAD REQUEST<br/>Error: "New passwords don't match"<br/>Password unchanged |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Cross-field validation |

---

### Test Case: PROF_BE_TC_009

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_BE_TC_009 |
| **Module Name** | Profile Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Forgot password - OTP request |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. POST `/api/auth/request-password-reset/`<br/>2. Provide registered email<br/>3. Verify OTP is generated and stored<br/>4. Verify OTP is sent via email<br/>5. Verify response contains masked email |
| **Test Data** | `email`: "user@example.com" |
| **Expected Result** | HTTP 200 OK<br/>OTP generated (6 digits)<br/>OTP sent to email<br/>OTP valid for 10 minutes<br/>Response: `{ success: true, masked_email: "us****@example.com" }` |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | OTPResetService handles generation and email |

---

### Test Case: PROF_BE_TC_010

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_BE_TC_010 |
| **Module Name** | Profile Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Reset password with OTP - valid OTP and new password |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Request password reset (get OTP)<br/>2. POST `/api/auth/verify-otp-reset/`<br/>3. Provide email, OTP, new password<br/>4. Verify OTP is marked as used<br/>5. Verify password is updated<br/>6. Verify login works with new password |
| **Test Data** | `email`: "user@example.com"<br/>`otp`: "123456"<br/>`new_password`: "ResetPass789!@#"<br/>`new_password2`: "ResetPass789!@#" |
| **Expected Result** | HTTP 200 OK<br/>OTP marked as used<br/>Password updated<br/>Old password no longer works<br/>New password works for login |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | OTP can only be used once |

---

### Test Case: PROF_BE_TC_011

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_BE_TC_011 |
| **Module Name** | Profile Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Reset password - invalid/expired OTP |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Request password reset (get OTP)<br/>2. Wait for OTP to expire (>10 min)<br/>3. POST `/api/auth/verify-otp-reset/` with expired OTP<br/>4. Verify error |
| **Test Data** | Expired OTP (older than 10 min) |
| **Expected Result** | HTTP 400 BAD REQUEST<br/>Error: "OTP has expired. Please request a new one."<br/>Password unchanged |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | OTP expiration enforced |

---

### Test Case: PROF_BE_TC_012

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_BE_TC_012 |
| **Module Name** | Profile Management |
| **Component** | Backend (Django) |
| **Test Scenario** | OTP invalid format/wrong code |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Request password reset (get OTP)<br/>2. POST `/api/auth/verify-otp-reset/` with wrong OTP<br/>3. Verify error<br/>4. Check OTP is not marked as used (can retry) |
| **Test Data** | Correct email, wrong OTP "000000" |
| **Expected Result** | HTTP 400 BAD REQUEST<br/>Error: "Invalid OTP"<br/>OTP not consumed (can try again)<br/>Original OTP still valid if not expired |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Multiple OTP attempts allowed |

---

---

## 2.2 Frontend Tests

### Test Case: PROF_FE_TC_001

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_FE_TC_001 |
| **Module Name** | Profile Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Display user profile on profile screen |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Login successfully<br/>2. Navigate to profile screen<br/>3. Verify user name is displayed<br/>4. Verify profile image is loaded and shown<br/>5. Verify email is displayed<br/>6. Verify join date is displayed<br/>7. Verify habit statistics are shown |
| **Test Data** | User: name="John Doe", email="john@example.com", profile_image="https://..." |
| **Expected Result** | Profile screen shows:<br/>- User name: "John Doe"<br/>- User email: "john@example.com"<br/>- Profile image loaded<br/>- Join date: "Joined Feb 2026"<br/>- Stats: habits, current streak, total completed |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test UI rendering and API integration |

---

### Test Case: PROF_FE_TC_002

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_FE_TC_002 |
| **Module Name** | Profile Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Edit profile - change name |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Navigate to profile screen<br/>2. Tap edit button<br/>3. Change name field to "Updated Name"<br/>4. Tap save button<br/>5. Verify loading indicator<br/>6. Verify success message<br/>7. Verify name updated on screen |
| **Test Data** | `name`: "Updated Name" |
| **Expected Result** | Edit mode enables<br/>Form can be edited<br/>Save button sends PATCH request<br/>Loading indicator shown<br/>Success notification<br/>Profile name updated immediately<br/>API request successful (200 OK) |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test form submission and API integration |

---

### Test Case: PROF_FE_TC_003

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_FE_TC_003 |
| **Module Name** | Profile Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Edit profile - profile image upload |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Navigate to profile edit screen<br/>2. Tap profile image section<br/>3. Select "Camera" or "Gallery"<br/>4. Select/capture image<br/>5. Verify image preview<br/>6. Tap save<br/>7. Verify image uploaded<br/>8. Verify new image displayed on profile |
| **Test Data** | Image file: profile_pic.jpg (2MB, JPEG) |
| **Expected Result** | Image picker opens<br/>Selected image shown in preview<br/>Upload to server<br/>Success notification<br/>New image immediately visible<br/>Profile image URL updated |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test image selection and upload flow |

---

### Test Case: PROF_FE_TC_004

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_FE_TC_004 |
| **Module Name** | Profile Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Edit profile - cancel changes |
| **Priority** | P2 - Medium |
| **Type** | Positive Test |
| **Test Steps** | 1. Navigate to profile edit screen<br/>2. Change name field<br/>3. Tap cancel button<br/>4. Verify confirmation dialog (if modified)<br/>5. Confirm cancellation<br/>6. Verify original name still displayed |
| **Test Data** | Original name: "John Doe", Changed to: "Jane Doe" |
| **Expected Result** | Confirmation dialog: "Discard changes?"<br/>On confirm: changes discarded<br/>Original name displayed<br/>No API request made |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test undo functionality |

---

### Test Case: PROF_FE_TC_005

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_FE_TC_005 |
| **Module Name** | Profile Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Change password - valid input |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Navigate to settings/profile<br/>2. Tap "Change Password"<br/>3. Enter current password<br/>4. Enter new password<br/>5. Confirm new password<br/>6. Verify form validation passes<br/>7. Tap save button<br/>8. Verify success message<br/>9. Verify logged out (redirected to login) |
| **Test Data** | `current`: "OldPass123!@#"<br/>`new`: "NewPass456!@#"<br/>`confirm`: "NewPass456!@#" |
| **Expected Result** | Form accepts input<br/>All fields validated<br/>API request: 200 OK<br/>Success message: "Password changed successfully"<br/>Auto-logout after 2 seconds<br/>Redirect to login screen<br/>Must re-login with new password |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test password change and session handling |

---

### Test Case: PROF_FE_TC_006

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_FE_TC_006 |
| **Module Name** | Profile Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Change password - current password incorrect |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Navigate to change password<br/>2. Enter wrong current password<br/>3. Enter new password correctly<br/>4. Tap save<br/>5. Verify error message |
| **Test Data** | `current`: "WrongPass999!@#"<br/>`new`: "NewPass456!@#" |
| **Expected Result** | Error message: "Current password is incorrect"<br/>No API request made (client-side) or 400 response (server-side)<br/>Form not cleared (can correct and retry)<br/>Password unchanged |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test input validation |

---

### Test Case: PROF_FE_TC_007

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_FE_TC_007 |
| **Module Name** | Profile Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Forgot password - OTP request |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Open login screen<br/>2. Tap "Forgot Password"<br/>3. Enter registered email<br/>4. Tap "Send OTP"<br/>5. Verify success message<br/>6. Verify OTP input screen appears<br/>7. Verify email masking feedback (e.g., "Check us****@email.com") |
| **Test Data** | `email`: "user@example.com" |
| **Expected Result** | Loading indicator shown<br/>API request: 200 OK<br/>Success message: "OTP sent to your email"<br/>OTP input screen shown<br/>Email display masked: "us****@example.com"<br/>Timer shown for OTP expiration |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test multi-step password reset flow |

---

### Test Case: PROF_FE_TC_008

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_FE_TC_008 |
| **Module Name** | Profile Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Verify OTP and reset password |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. On OTP screen, enter 6-digit OTP<br/>2. Verify OTP input accepts digits only<br/>3. Tap "Verify OTP"<br/>4. Verify new password screen appears<br/>5. Enter new password<br/>6. Confirm new password<br/>7. Tap "Reset Password"<br/>8. Verify success message<br/>9. Verify redirect to login screen |
| **Test Data** | `otp`: "123456"<br/>`new_password`: "ResetPass789!@#"<br/>`confirm`: "ResetPass789!@#" |
| **Expected Result** | OTP field accepts 6 digits<br/>API verification: 200 OK<br/>Password reset screen shown<br/>Password fields validated<br/>Reset successful<br/>Redirect to login<br/>Can login with new password |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test multi-step password reset completion |

---

### Test Case: PROF_FE_TC_009

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_FE_TC_009 |
| **Module Name** | Profile Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | OTP resend functionality |
| **Priority** | P2 - Medium |
| **Type** | Positive Test |
| **Test Steps** | 1. On OTP input screen<br/>2. Verify timer shows OTP expiration (e.g., "Expires in 10m")<br/>3. Tap "Resend OTP" button<br/>4. Verify loading indicator<br/>5. Verify success message<br/>6. Verify timer resets |
| **Test Data** | Original OTP expired or request a new one |
| **Expected Result** | Resend button enabled<br/>New OTP sent to email<br/>Success message shown<br/>Timer resets to 10 minutes<br/>Can use new OTP |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test error recovery flow |

---

### Test Case: PROF_FE_TC_010

| Aspect | Details |
|--------|---------|
| **Test Case ID** | PROF_FE_TC_010 |
| **Module Name** | Profile Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | View login history |
| **Priority** | P2 - Medium |
| **Type** | Positive Test |
| **Test Steps** | 1. Navigate to settings/profile<br/>2. Tap "Login History"<br/>3. Verify list of recent logins displayed<br/>4. Verify each entry shows: date, time, device, location<br/>5. Verify timestamp formatted (e.g., "Today at 10:30 AM") |
| **Test Data** | Multiple login records in database |
| **Expected Result** | Login list shows recent logins first<br/>Each entry displays:<br/>- Timestamp<br/>- Device type (iOS/Android/Web)<br/>- Approximate location<br/>- IP address last octet<br/>- "Current session" badge on active login |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Security feature showing account access |

---

---

# MODULE 3: HABIT CREATION & MANAGEMENT

## 3.1 Backend Tests

### Test Case: HABIT_BE_TC_001

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_001 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Create habit with all required fields |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user<br/>2. POST `/api/habits/`<br/>3. Provide required fields: title, description, category, frequency<br/>4. Verify habit is created<br/>5. Verify Streak record is auto-created<br/>6. Verify habit appears in user's habit list |
| **Test Data** | `title`: "Morning Exercise"<br/>`description`: "30 mins cardio"<br/>`category`: 1 (id)<br/>`frequency`: "daily"<br/>`priority`: "high"<br/>`reminder_time`: "07:00:00" |
| **Expected Result** | HTTP 201 CREATED<br/>Habit created with status='active'<br/>Streak record created with zero values<br/>User can immediately see habit in list<br/>Response includes habit ID and metadata |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Foreign key relationship to Category |

---

### Test Case: HABIT_BE_TC_002

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_002 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Create habit without required field |
| **Priority** | P0 - Critical |
| **Type** | Negative Test |
| **Test Steps** | 1. Authenticate as user<br/>2. POST `/api/habits/` without title<br/>3. Verify validation error |
| **Test Data** | Missing `title` field |
| **Expected Result** | HTTP 400 BAD REQUEST<br/>Error: "This field is required."<br/>No habit created |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | title is required field in model |

---

### Test Case: HABIT_BE_TC_003

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_003 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Create habit with invalid category |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Authenticate as user<br/>2. POST `/api/habits/` with non-existent category ID<br/>3. Verify error |
| **Test Data** | `category`: 99999 (non-existent) |
| **Expected Result** | HTTP 400 BAD REQUEST<br/>Error: "Invalid category"<br/>No habit created |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | ForeignKey validation |

---

### Test Case: HABIT_BE_TC_004

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_004 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | List user's habits filtered by status |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user with multiple habits<br/>2. GET `/api/habits/?status=active`<br/>3. Verify only active habits returned<br/>4. Verify pagination works (limit=10, offset=0) |
| **Test Data** | User has 3 active, 2 paused, 1 archived habits |
| **Expected Result** | HTTP 200 OK<br/>Response: array of 3 active habits<br/>Each habit includes: id, title, status, streak info<br/>Pagination metadata: count, next, previous |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Custom filtering in get_queryset |

---

### Test Case: HABIT_BE_TC_005

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_005 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Get habits for today with progress |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user<br/>2. GET `/api/habits/today/`<br/>3. Verify habits for current day returned<br/>4. Verify each habit includes isCompleted flag<br/>5. Verify streak info included |
| **Test Data** | User with habits, some completed today |
| **Expected Result** | HTTP 200 OK<br/>Habits list with computed fields:<br/>- isCompleted: true/false (based on today's log)<br/>- currentStreak: integer<br/>- daysUntilLoss: integer<br/>- lastCompletedDate: date |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | TodayHabitSerializer with computed fields |

---

### Test Case: HABIT_BE_TC_006

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_006 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Update habit - change frequency |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user<br/>2. PATCH `/api/habits/{id}/`<br/>3. Change frequency from "daily" to "weekly"<br/>4. Verify habit updated<br/>5. Verify streak not reset |
| **Test Data** | Habit ID=5, new frequency="weekly" |
| **Expected Result** | HTTP 200 OK<br/>Frequency updated in database<br/>Streak history preserved<br/>Updated_at timestamp changed |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Partial update with PATCH |

---

### Test Case: HABIT_BE_TC_007

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_007 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Delete habit (soft delete) |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user<br/>2. DELETE `/api/habits/{id}/`<br/>3. Verify habit no longer in active list<br/>4. Verify deleted_at timestamp is set<br/>5. Verify data in database is preserved |
| **Test Data** | Habit ID=3 to be deleted |
| **Expected Result** | HTTP 204 NO CONTENT<br/>Habit soft-deleted (marked with deleted_at)<br/>Habit not in GET `/api/habits/` response<br/>Habit record still in database for audit |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Soft delete using django-paranoid or custom logic |

---

### Test Case: HABIT_BE_TC_008

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_008 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Pause habit - freeze streak |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user with active habit<br/>2. POST `/api/habits/{id}/pause/`<br/>3. Verify habit status changed to "paused"<br/>4. Verify yesterday's completion doesn't break streak<br/>5. Verify habit not shown in today's habits |
| **Test Data** | Habit ID=2 with current_streak=10 |
| **Expected Result** | HTTP 200 OK<br/>Status changed to "paused"<br/>Streak value preserved<br/>Habit not counted in "today" endpoint<br/>Can be resumed later |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Status transitions: active → paused ↔ archived |

---

### Test Case: HABIT_BE_TC_009

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_009 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Resume paused habit |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Pause a habit<br/>2. POST `/api/habits/{id}/resume/`<br/>3. Verify status changed back to "active"<br/>4. Verify streak restored<br/>5. Verify habit appears in today's list |
| **Test Data** | Paused habit with ID=2 |
| **Expected Result** | HTTP 200 OK<br/>Status changed to "active"<br/>Habit appears in today's habits<br/>Streak calculation resumes<br/>Completion logging resumes |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | State transition validation |

---

### Test Case: HABIT_BE_TC_010

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_010 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Habit color customization |
| **Priority** | P2 - Medium |
| **Type** | Positive Test |
| **Test Steps** | 1. CREATE or UPDATE habit with custom color<br/>2. Provide color_value as integer (ARGB format)<br/>3. Verify color stored in database<br/>4. Verify color returned in API responses |
| **Test Data** | `color_value`: 4294198070 (Blue in ARGB) |
| **Expected Result** | HTTP 201/200 OK<br/>Color value stored<br/>Color persisted in database<br/>Clients can display custom color |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | ARGB format used in Flutter |

---

### Test Case: HABIT_BE_TC_011

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_011 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Habit icon customization |
| **Priority** | P2 - Medium |
| **Type** | Positive Test |
| **Test Steps** | 1. CREATE or UPDATE habit with custom icon<br/>2. Provide icon_code as Material Icons codePoint<br/>3. Verify icon stored<br/>4. Verify icon returned in responses |
| **Test Data** | `icon_code`: 0xE163 (Running man icon) |
| **Expected Result** | HTTP 201/200 OK<br/>Icon code stored<br/>Icon persisted in database<br/>Clients can render icon |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Material Icons codePoint values |

---

### Test Case: HABIT_BE_TC_012

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_012 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Reorder habits with drag-and-drop |
| **Priority** | P2 - Medium |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user with multiple habits<br/>2. POST `/api/habits/reorder/`<br/>3. Provide new order as list of habit IDs<br/>4. Verify order_index updated for each habit<br/>5. Verify GET list returns habits in new order |
| **Test Data** | `habit_ids`: [5, 2, 8, 1, 3] |
| **Expected Result** | HTTP 200 OK<br/>Order_index updated:<br/>Habit 5: order_index=0<br/>Habit 2: order_index=1<br/>...and so on<br/>List endpoint returns in new order |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Bulk update operation |

---

### Test Case: HABIT_BE_TC_013

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_013 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Partial completion tracking |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Create a quantified habit (e.g., "Read 100 pages")<br/>2. POST `/api/habits/{id}/partial-complete/`<br/>3. Provide progress value<br/>4. Verify HabitLog is created with status and partial score/count<br/>5. Verify XP awarded based on progress |
| **Test Data** | Habit: "Read 100 pages" (goal=100)<br/>Post data: `count`: 50 |
| **Expected Result** | HTTP 200 OK<br/>HabitLog created: status="partial", count=50<br/>XP awarded proportionally (50% of full XP)<br/>Completion percentage shown in response |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Supports quantified habits |

---

### Test Case: HABIT_BE_TC_014

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_014 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Habit statistics endpoint |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user<br/>2. GET `/api/habits/{id}/stats/`<br/>3. Verify statistics returned |
| **Test Data** | Habit with long completion history |
| **Expected Result** | HTTP 200 OK<br/>Response includes:<br/>- current_streak: 10<br/>- best_streak: 25<br/>- total_completions: 150<br/>- total_skips: 5<br/>- total_misses: 8<br/>- completion_rate: 94.5%<br/>- last_completed_date: "2026-03-28"<br/>- streak_start_date: "2026-03-19" |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Computed from Streak model |

---

### Test Case: HABIT_BE_TC_015

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_015 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Habit history pagination |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user with habit having many logs<br/>2. GET `/api/habits/{id}/history/?limit=30&offset=0`<br/>3. Verify paginated response<br/>4. Verify total count provided<br/>5. Verify can navigate pages |
| **Test Data** | Habit with 1000 HabitLog entries |
| **Expected Result** | HTTP 200 OK<br/>Response:<br/>- count: 1000 (total)<br/>- next: "/api/.../history/?limit=30&offset=30"<br/>- previous: null<br/>- results: [30 items]<br/>Each item: date, status, notes, mood |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Cursor or offset-based pagination |

---

### Test Case: HABIT_BE_TC_016

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_016 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Category listing - default and custom |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user<br/>2. GET `/api/habits/categories/`<br/>3. Verify default categories returned<br/>4. Verify user's custom categories included |
| **Test Data** | Backend seeded with 5 default categories |
| **Expected Result** | HTTP 200 OK<br/>Response: array of categories<br/>Each category: id, name, icon_code, color_value, is_default<br/>Default categories: Health, Fitness, Learning, Work, Finance, etc.<br/>User custom categories marked with is_default=false |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Category seeding in migrations |

---

### Test Case: HABIT_BE_TC_017

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_017 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Summary statistics across all habits |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Authenticate as user with multiple habits<br/>2. GET `/api/habits/stats_summary/`<br/>3. Verify aggregate statistics returned |
| **Test Data** | User with 10 habits, various streaks |
| **Expected Result** | HTTP 200 OK<br/>Response:<br/>- total_habits: 10<br/>- active_habits: 8<br/>- paused_habits: 2<br/>- current_overall_streak: 7<br/>- best_overall_streak: 30<br/>- today_completion_rate: 70%<br/>- this_week_completion: 45/56<br/>- this_month_completion: 180/240 |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Aggregated from all user's habits |

---

### Test Case: HABIT_BE_TC_018

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_BE_TC_018 |
| **Module Name** | Habit Creation & Management |
| **Component** | Backend (Django) |
| **Test Scenario** | Cannot access other user's habits |
| **Priority** | P0 - Critical |
| **Type** | Negative Test |
| **Test Steps** | 1. Authenticate as User A<br/>2. Attempt to GET `/api/habits/?user_id=2` (User B's habits)<br/>3. Verify access denied or filtered to own habits |
| **Test Data** | User A token, trying to access User B's habits |
| **Expected Result** | Only User A's habits returned<br/>User B's habits never visible<br/>No error thrown (transparent to user)<br/>If explicit user_id provided, ignored |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | get_queryset filters by current user |

---

## 3.2 Frontend Tests

### Test Case: HABIT_FE_TC_001

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_001 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Create habit - form validation and submission |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Open home screen<br/>2. Tap "Add Habit" button<br/>3. Enter habit title<br/>4. Select category from dropdown<br/>5. Select frequency (daily/weekly/monthly)<br/>6. Set reminder time<br/>7. Verify form validation passes<br/>8. Tap "Create" button<br/>9. Verify habit appears in list<br/>10. Verify success notification |
| **Test Data** | `title`: "Morning Run"<br/>`category`: "Fitness"<br/>`frequency`: "Daily"<br/>`reminded_time`: "06:00 AM"<br/>`priority`: "High" |
| **Expected Result** | Form fields render properly<br/>Category dropdown populated<br/>Frequency selector shows options<br/>Time picker works<br/>Submit button sends POST request<br/>Loading indicator shown<br/>Habit added to list<br/>Success notification: "Habit created!"<br/>New habit appears at top of list |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test form UX and API integration |

---

### Test Case: HABIT_FE_TC_002

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_002 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Habit creation - title validation |
| **Priority** | P1 - High |
| **Type** | Negative Test |
| **Test Steps** | 1. Open create habit screen<br/>2. Leave title empty<br/>3. Tap outside title field<br/>4. Verify error message appears<br/>5. Verify submit button disabled |
| **Test Data** | Empty title field |
| **Expected Result** | Error message: "Title is required"<br/>Red underline on field<br/>Submit button disabled (grayed out)<br/>Form not submitted |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Real-time validation |

---

### Test Case: HABIT_FE_TC_003

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_003 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Habit creation - category selection |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Open create habit screen<br/>2. Tap category dropdown<br/>3. Verify dropdown shows default categories<br/>4. Scroll in dropdown to see all options<br/>5. Select "Health"<br/>6. Verify selected value shown in field<br/>7. Verify icon and color displayed |
| **Test Data** | Category list: Health, Fitness, Learning, Work, Finance |
| **Expected Result** | Dropdown opens with all categories<br/>Each category shows icon and name<br/>Selected category highlighted<br/>Selected value persists in field<br/>Color preview shown<br/>Can change selection |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test dropdown UX |

---

### Test Case: HABIT_FE_TC_004

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_004 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Display habits list with progress indicators |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Login and open home screen<br/>2. Verify habits list displayed<br/>3. Each habit shows: title, category, current streak<br/>4. Verify completion checkbox available<br/>5. Verify habit color matches selected color<br/>6. Verify streak number highlighted |
| **Test Data** | Multiple habits with different streaks: 5, 12, 0 |
| **Expected Result** | List displays all active habits<br/>Each item shows:<br/>- Habit title<br/>- Category badge with icon<br/>- Current streak: "12 days"<br/>- Unchecked checkbox<br/>- Custom color background<br/>- Habit can be tapped for details |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test habit list rendering |

---

### Test Case: HABIT_FE_TC_005

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_005 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Mark habit complete with button tap |
| **Priority** | P0 - Critical |
| **Type** | Positive Test |
| **Test Steps** | 1. Open home screen with uncompleted habit<br/>2. Tap checkbox next to habit<br/>3. Verify checkbox becomes checked<br/>4. Verify API request sent (toggling completion)<br/>5. Verify streak increments (if streak continuing)<br/>6. Verify success feedback given |
| **Test Data** | Habit: "Morning Run", current_streak: "5 days" |
| **Expected Result** | Checkbox shows checked state<br/>Button disables briefly during API call<br/>API POST request: `/api/habits/{id}/toggle-complete/`<br/>Streak updates: "6 days"<br/>Success feedback (brief notification or visual pulse)<br/>UI updates immediately |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test toggle behavior and optimistic updates |

---

### Test Case: HABIT_FE_TC_006

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_006 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Unmark completed habit |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Open home with completed habit (checkbox checked)<br/>2. Tap checkbox to uncheck<br/>3. Verify checkbox becomes unchecked<br/>4. Verify API request sent<br/>5. Verify streak decrements if applicable<br/>6. Verify undo option available (brief window) |
| **Test Data** | Completed habit with streak: "6 days" |
| **Expected Result** | Checkbox unchecked<br/>Streak decreases back to "5 days"<br/>Optional: Toast with "Undo" button for 3 seconds<br/>If undo tapped, reverts to checked state<br/>API request sent on final state |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test toggle and undo UX |

---

### Test Case: HABIT_FE_TC_007

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_007 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Edit habit - basic information |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Open habit details screen<br/>2. Tap edit button<br/>3. Modify habit title<br/>4. Change category<br/>5. Change reminder time<br/>6. Tap save button<br/>7. Verify changes persisted<br/>8. Verify success message |
| **Test Data** | Original: "Morning Run" → New: "Morning Jog"<br/>Original category: "Fitness" → New: "Health" |
| **Expected Result** | Edit form populated with current values<br/>Fields editable<br/>Save button sends PATCH request<br/>Loading indicator shown<br/>Success message: "Habit updated"<br/>Changes reflected in list view<br/>Details screen updated |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test edit form and persistence |

---

### Test Case: HABIT_FE_TC_008

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_008 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Delete habit with confirmation |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Open habit details<br/>2. Tap delete button (trash icon)<br/>3. Verify confirmation dialog shows<br/>4. Tap "Delete" to confirm<br/>5. Verify loading indicator<br/>6. Verify habit removed from list<br/>7. Verify success message |
| **Test Data** | Habit to be deleted: "Meditation" |
| **Expected Result** | Confirmation dialog: "Delete 'Meditation'? This cannot be undone."<br/>Cancel and Delete buttons<br/>On Delete: API DELETE request sent<br/>Loading state<br/>Habit removed from list<br/>Success toast: "Habit deleted"<br/>User returned to home screen or list updates |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test deletion confirmation UX |

---

### Test Case: HABIT_FE_TC_009

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_009 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Pause habit functionality |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Open habit with current streak<br/>2. Tap pause button<br/>3. Verify confirmation dialog<br/>4. Confirm pause<br/>5. Verify habit moved to paused section<br/>6. Verify checkbox disabled for paused habit<br/>7. Verify streak frozen |
| **Test Data** | Habit: "Reading", current_streak: "10 days" |
| **Expected Result** | Confirmation: "Pause 'Reading'? Your streak will be preserved."<br/>On confirm: habit moves to paused list<br/>Paused section shows habit<br/>Checkbox disabled/grayed out<br/>Streak still visible: "10 days (paused)"<br/>Resume button available |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test habit state transitions |

---

### Test Case: HABIT_FE_TC_010

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_010 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Resume paused habit |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Open paused habit<br/>2. Tap resume button<br/>3. Verify confirmation dialog<br/>4. Confirm resume<br/>5. Verify habit moved back to active list<br/>6. Verify checkbox enabled<br/>7. Verify streak resumes calculating |
| **Test Data** | Paused habit to resume |
| **Expected Result** | Confirmation: "Resume 'Reading'?"<br/>On confirm: habit moves to active list<br/>Checkbox enabled<br/>Complete status restored<br/>Can mark complete immediately<br/>Streak updates normally |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test state restoration |

---

### Test Case: HABIT_FE_TC_011

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_011 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Habit details screen with history |
| **Priority** | P1 - High |
| **Type** | Positive Test |
| **Test Steps** | 1. Open habit details<br/>2. Verify habit info displayed: title, category, streak<br/>3. Scroll to history section<br/>4. Verify calendar or list of completions<br/>5. Verify dates with checkmarks for completed days<br/>6. Verify swipe/scroll for month navigation |
| **Test Data** | Habit with 30-day history, 20 completions, 5 skips |
| **Expected Result** | Details show:<br/>- Title, description<br/>- Current: 8 days, Best: 25 days<br/>- Completion rate: 66.7%<br/>- Calendar with completion dots<br/>- Completed days: ✓ (green)<br/>- Skipped days: ⊘ (yellow)<br/>- Missed days: ✗ (gray)<br/>Can navigate previous/next months<br/>Tap on date shows that day's notes |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test detailed history view |

---

### Test Case: HABIT_FE_TC_012

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_012 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Add completion notes and mood rating |
| **Priority** | P2 - Medium |
| **Type** | Positive Test |
| **Test Steps** | 1. Mark habit complete<br/>2. Optional: modal appears for notes<br/>3. Enter notes: "Felt energetic today"<br/>4. Select mood rating (1-5 stars or emoji)<br/>5. Tap confirm<br/>6. Verify notes saved<br/>7. Verify mood saved in history |
| **Test Data** | `notes`: "Great session!"<br/>`mood_rating`: 4 (out of 5) |
| **Expected Result** | Modal shows notes field<br/>Mood picker (stars/emoji)<br/>Optional fields<br/>Save sends data to API<br/>Notes visible in habit details<br/>Mood rating shown in calendar/history |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test metadata capture |

---

### Test Case: HABIT_FE_TC_013

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_013 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Skip habit with reason |
| **Priority** | P2 - Medium |
| **Type** | Positive Test |
| **Test Steps** | 1. Open habit for today<br/>2. Tap "Skip" button (alternative to complete)<br/>3. Optional modal for skip reason<br/>4. Select or enter reason: "Traveling"<br/>5. Tap confirm<br/>6. Verify habit marked as skipped<br/>7. Verify streak not affected<br/>8. Verify reason saved |
| **Test Data** | Skip reason: "Busy schedule" |
| **Expected Result** | Skip button visible on habit card<br/>Modal appears with reason options<br/>Skip recorded in history<br/>Streak preserved<br/>Calendar shows skip indicator<br/>Reasons tracked for analytics |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test skip functionality |

---

### Test Case: HABIT_FE_TC_014

| Aspect | Details |
|--------|---------|
| **Test Case ID** | HABIT_FE_TC_014 |
| **Module Name** | Habit Creation & Management |
| **Component** | Frontend (Flutter) |
| **Test Scenario** | Filter habits by category |
| **Priority** | P2 - Medium |
| **Type** | Positive Test |
| **Test Steps** | 1. Open home screen<br/>2. Tap category filter button<br/>3. Select category: "Fitness"<br/>4. Verify list shows only Fitness habits<br/>5. Verify other categories hidden<br/>6. Tap category again to clear filter |
| **Test Data** | Categories: Health (3), Fitness (5), Learning (2) |
| **Expected Result** | Filter button shows selected category<br/>List updates to show only Fitness (5 habits)<br/>Clear filter button appears<br/>Can select multiple categories<br/>Count updates dynamically |
| **Actual Result** | [Pending Testing] |
| **Status** | PENDING |
| **Notes** | Test filtering UX |

---

---

# MODULE 4: HABIT TRACKING & STREAK SYSTEM

## 4.1 Backend Tests

| Test Case ID | Module Name | Component | Type | Test Scenario | Test Steps | Test Data | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|---|---|---|---|
| HABTRK_BE_TC_001 | Habit Tracking & Streak System | Backend (Django) | Positive | Toggle completion creates today's completed log | 1. Authenticate as user<br/>2. POST `/api/habits/{habit_id}/toggle-complete/`<br/>3. GET `/api/habits/{habit_id}/history/` | Habit status=`active` and no log for today | 200 OK<br/>Today's HabitLog exists with `status=completed` and a non-null completion timestamp<br/>Streak fields reflect completion (current/best updated per rules) |  | PENDING |
| HABTRK_BE_TC_002 | Habit Tracking & Streak System | Backend (Django) | Edge | Toggle completion twice is idempotent (un-complete) | 1. Call toggle-complete to complete<br/>2. Call toggle-complete again<br/>3. GET history | Same habit, same day | 200 OK both times<br/>Second call removes/reverts today's completion entry per implementation<br/>Subsequent serialization shows `isCompleted=false` |  | PENDING |
| HABTRK_BE_TC_003 | Habit Tracking & Streak System | Backend (Django) | Positive | Skip habit with optional reason | 1. Authenticate<br/>2. POST `/api/habits/{habit_id}/skip/` with reason<br/>3. GET `/api/habits/{habit_id}/history/` | `reason`: "Traveling" | 200 OK<br/>Today's log status becomes `skipped` (upsert behavior)<br/>Skip reason stored in log notes or metadata<br/>Streak skip counters increment, no streak increment |  | PENDING |
| HABTRK_BE_TC_004 | Habit Tracking & Streak System | Backend (Django) | Negative | Skip non-existent habit | 1. Authenticate<br/>2. POST `/api/habits/999999/skip/` | Invalid habit_id | 404 NOT FOUND |  | PENDING |
| HABTRK_BE_TC_005 | Habit Tracking & Streak System | Backend (Django) | Negative | Cannot complete habit belonging to another user | 1. Authenticate as user A<br/>2. POST `/api/habits/{habit_id_owned_by_user_b}/toggle-complete/` | Cross-tenant habit id | 404 NOT FOUND (preferred) or 403 FORBIDDEN<br/>No information leak of other user’s data |  | PENDING |
| HABTRK_BE_TC_006 | Habit Tracking & Streak System | Backend (Django) | Positive | Partial completion clamps score (0.0–1.0) | 1. Authenticate<br/>2. POST `/api/habits/{habit_id}/partial-complete/` with `score=1.5`<br/>3. Repeat with `score=-0.2` | score out of range | 200 OK<br/>Server clamps and persists score within [0.0,1.0]<br/>HabitLog created/updated with `status=partial` and valid score |  | PENDING |
| HABTRK_BE_TC_007 | Habit Tracking & Streak System | Backend (Django) | Negative | Partial completion validation error | 1. Authenticate<br/>2. POST `/api/habits/{habit_id}/partial-complete/` with empty body | Missing score/count | 400 BAD REQUEST<br/>Validation error returned<br/>No log/streak changes |  | PENDING |
| HABTRK_BE_TC_008 | Habit Tracking & Streak System | Backend (Django) | Positive | Habit log CRUD via HabitLogViewSet is scoped to user | 1. Authenticate<br/>2. POST `/api/habit-logs/` for a habit you own<br/>3. Attempt POST for another user’s habit | Two habits (own vs other) | Own habit: 201 CREATED<br/>Other user habit: 404/403 and no log created |  | PENDING |
| HABTRK_BE_TC_009 | Habit Tracking & Streak System | Backend (Django) | Edge | Streak increments for consecutive completions | 1. Ensure habit completed yesterday (fixture)<br/>2. POST toggle-complete today<br/>3. GET habit details | Yesterday + today completed | `current_streak` increases by 1, `best_streak` updates if exceeded |  | PENDING |
| HABTRK_BE_TC_010 | Habit Tracking & Streak System | Backend (Django) | Edge | Streak reset after a missed day | 1. Complete on day D-2<br/>2. No action on D-1 (miss)<br/>3. Complete on day D | One-day gap | `current_streak` resets according to streak rules (typically to 1 on day D)<br/>Historical best is preserved |  | PENDING |
| HABTRK_BE_TC_011 | Habit Tracking & Streak System | Backend (Django) | Negative | Cannot complete paused habit | 1. POST `/api/habits/{id}/pause/`<br/>2. POST `/api/habits/{id}/toggle-complete/` | Paused habit | 400 BAD REQUEST (or 409 CONFLICT)<br/>No completion log created/updated |  | PENDING |
| HABTRK_BE_TC_012 | Habit Tracking & Streak System | Backend (Django) | Positive | Today endpoint returns active scheduled habits + progress | 1. Authenticate<br/>2. GET `/api/habits/today/` | Mixed habits | 200 OK<br/>List includes only active habits scheduled for today and per-habit `isCompleted` computed correctly |  | PENDING |

---

## 4.2 Frontend Tests

| Test Case ID | Module Name | Component | Type | Test Scenario | Test Steps | Test Data | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|---|---|---|---|
| HABTRK_FE_TC_001 | Habit Tracking & Streak System | Frontend (Flutter) | Positive | Completing a habit updates card state | 1. Open Today list on Home screen<br/>2. Tap checkbox/complete button<br/>3. Verify visual state changes | Habit `isCompleted=false` | Card shows completed state (checked/disabled styling)<br/>Streak badge updates after response (or optimistic update) |  | PENDING |
| HABTRK_FE_TC_002 | Habit Tracking & Streak System | Frontend (Flutter) | Negative | Completion API 500 shows error and reverts UI | 1. Mock toggle-complete to return 500<br/>2. Tap complete<br/>3. Verify UI rollback | 500 | Error snackbar/dialog appears<br/>Checkbox returns to previous state<br/>Retry possible |  | PENDING |
| HABTRK_FE_TC_003 | Habit Tracking & Streak System | Frontend (Flutter) | Positive | Skip habit with reason modal | 1. Tap "Skip" for a habit<br/>2. Enter/select reason<br/>3. Confirm | Reason="Sick" | Habit shows skipped state; reason shown in history/details<br/>No streak increase shown |  | PENDING |
| HABTRK_FE_TC_004 | Habit Tracking & Streak System | Frontend (Flutter) | Edge | Double tap protection during completion | 1. Rapidly tap complete button twice<br/>2. Verify only one request is sent | Rapid taps | UI disables control while loading; no duplicate completions |  | PENDING |
| HABTRK_FE_TC_005 | Habit Tracking & Streak System | Frontend (Flutter) | Positive | History screen renders logs correctly | 1. Open habit details<br/>2. Open history list/calendar section | Habit with logs | Correct icons for completed/skipped/missed<br/>Dates formatted properly; no rendering overflow |  | PENDING |
| HABTRK_FE_TC_006 | Habit Tracking & Streak System | Frontend (Flutter) | Positive | Partial completion input clamps bounds | 1. Open quantified habit partial-complete UI<br/>2. Enter values <0 or >max<br/>3. Submit | Out-of-range values | UI clamps to valid range before sending<br/>Displays server-confirmed partial score |  | PENDING |
| HABTRK_FE_TC_007 | Habit Tracking & Streak System | Frontend (Flutter) | Negative | Paused habit cannot be completed | 1. Pause habit from details<br/>2. Return to Today list<br/>3. Attempt completion | Paused habit | Completion controls disabled or show guidance message; no API call fired |  | PENDING |
| HABTRK_FE_TC_008 | Habit Tracking & Streak System | Frontend (Flutter) | Edge | App stays stable across day boundary | 1. Keep app in foreground over midnight<br/>2. Refresh Today list | Midnight boundary | Today date changes; list recomputed; no stale completion state or crash |  | PENDING |
| HABTRK_FE_TC_009 | Habit Tracking & Streak System | Frontend (Flutter) | Positive | Loading states for history pagination | 1. Scroll history to bottom<br/>2. Trigger load more | Large history | Shows inline loader, appends results, no duplicates |  | PENDING |
| HABTRK_FE_TC_010 | Habit Tracking & Streak System | Frontend (Flutter) | Negative | Unauthorized session shows login redirect | 1. Mock 401 from Today endpoint<br/>2. Open Home screen | 401 | App shows auth-expired UX and routes to login (or prompts re-auth) |  | PENDING |

---

# MODULE 5: DASHBOARD & ANALYTICS

## 5.1 Backend Tests

| Test Case ID | Module Name | Component | Type | Test Scenario | Test Steps | Test Data | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|---|---|---|---|
| ANLY_BE_TC_001 | Dashboard & Analytics | Backend (Django) | Positive | Dashboard endpoint returns composite payload | 1. Authenticate<br/>2. GET `/api/analytics/dashboard/` | User with mixed logs | 200 OK<br/>Top-level `success=true` and `data` includes `summary` and `weeklyData` (per implementation) |  | PENDING |
| ANLY_BE_TC_002 | Dashboard & Analytics | Backend (Django) | Positive | Weekly endpoint default | 1. Authenticate<br/>2. GET `/api/analytics/weekly/` | None | 200 OK<br/>Returns 7-day dataset for current week |  | PENDING |
| ANLY_BE_TC_003 | Dashboard & Analytics | Backend (Django) | Edge | Weekly weeksBack parameter | 1. Authenticate<br/>2. GET `/api/analytics/weekly/?weeksBack=4` | weeksBack=4 | 200 OK<br/>Week selection matches expected date range |  | PENDING |
| ANLY_BE_TC_004 | Dashboard & Analytics | Backend (Django) | Negative | Weekly invalid weeksBack should not 500 | 1. Authenticate<br/>2. GET `/api/analytics/weekly/?weeksBack=abc` | weeksBack=abc | 400 BAD REQUEST (preferred) OR safe fallback to 0<br/>No 500 error |  | PENDING |
| ANLY_BE_TC_005 | Dashboard & Analytics | Backend (Django) | Positive | Monthly heatmap for specific month | 1. Authenticate<br/>2. GET `/api/analytics/monthly/?year=2026&month=3` | year=2026 month=3 | 200 OK<br/>Calendar payload contains entries for each day of the month |  | PENDING |
| ANLY_BE_TC_006 | Dashboard & Analytics | Backend (Django) | Negative | Monthly invalid month boundary | 1. Authenticate<br/>2. GET `/api/analytics/monthly/?year=2026&month=13` | month=13 | 400 BAD REQUEST with clear validation error |  | PENDING |
| ANLY_BE_TC_007 | Dashboard & Analytics | Backend (Django) | Positive | Category breakdown endpoint | 1. Authenticate<br/>2. GET `/api/analytics/category-breakdown/` | Existing categories | 200 OK<br/>Per-category stats returned with consistent totals |  | PENDING |
| ANLY_BE_TC_008 | Dashboard & Analytics | Backend (Django) | Positive | Trend endpoint provides time series | 1. Authenticate<br/>2. GET `/api/analytics/trend/?days=30` | days=30 | 200 OK<br/>Dates ordered correctly and length <= 30 |  | PENDING |
| ANLY_BE_TC_009 | Dashboard & Analytics | Backend (Django) | Negative | Unauthorized analytics access | 1. GET `/api/analytics/dashboard/` without auth | No token | 401 UNAUTHORIZED |  | PENDING |
| ANLY_BE_TC_010 | Dashboard & Analytics | Backend (Django) | Edge | Analytics for user with zero habits | 1. Authenticate user with no habits<br/>2. GET dashboard/weekly/monthly | Empty user | 200 OK<br/>Rates are 0 and no division-by-zero occurs; returns empty/zeroed datasets |  | PENDING |

---

## 5.2 Frontend Tests

| Test Case ID | Module Name | Component | Type | Test Scenario | Test Steps | Test Data | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|---|---|---|---|
| ANLY_FE_TC_001 | Dashboard & Analytics | Frontend (Flutter) | Positive | Dashboard UI renders summary + weekly chart | 1. Navigate to analytics screen<br/>2. Verify summary cards<br/>3. Verify weekly chart present | Mock response | No layout overflow; values formatted correctly |  | PENDING |
| ANLY_FE_TC_002 | Dashboard & Analytics | Frontend (Flutter) | Negative | Dashboard API error renders retry state | 1. Mock 500 from analytics service<br/>2. Open screen | 500 | Error UI + retry button; no crash |  | PENDING |
| ANLY_FE_TC_003 | Dashboard & Analytics | Frontend (Flutter) | Positive | Pull-to-refresh re-fetches analytics | 1. Pull to refresh on analytics screen | Updated payload | Loader visible; data updates after refresh |  | PENDING |
| ANLY_FE_TC_004 | Dashboard & Analytics | Frontend (Flutter) | Edge | Monthly heatmap empty-state rendering | 1. Navigate to monthly heatmap view<br/>2. Mock empty list | Empty month | "No data yet" message shown; view still usable |  | PENDING |
| ANLY_FE_TC_005 | Dashboard & Analytics | Frontend (Flutter) | Positive | Category breakdown chart/legend | 1. Open category breakdown tab<br/>2. Verify legend color mapping | Mock breakdown | Legend and values match data; percentages sum approximately to 100% |  | PENDING |
| ANLY_FE_TC_006 | Dashboard & Analytics | Frontend (Flutter) | Edge | Large numbers do not overflow | 1. Mock very large completion counts<br/>2. Render dashboard | 10,000+ | Numbers are formatted and UI does not overflow/truncate unexpectedly |  | PENDING |
| ANLY_FE_TC_007 | Dashboard & Analytics | Frontend (Flutter) | Negative | Null/missing optional fields do not crash | 1. Mock response missing optional keys<br/>2. Render | Missing fields | App uses defaults; no runtime exception |  | PENDING |
| ANLY_FE_TC_008 | Dashboard & Analytics | Frontend (Flutter) | Negative | 401 during analytics call triggers auth UX | 1. Mock 401 from analytics endpoints | 401 | Redirect to login or show session-expired state; no infinite spinner |  | PENDING |

---

# MODULE 6: NOTIFICATIONS & REMINDERS

## 6.1 Backend Tests

| Test Case ID | Module Name | Component | Type | Test Scenario | Test Steps | Test Data | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|---|---|---|---|
| NOTIF_BE_TC_001 | Notifications & Reminders | Backend (Django) | Positive | List notifications includes unreadCount | 1. Authenticate<br/>2. GET `/api/notifications/` | Seeded notifications | 200 OK<br/>Returns `notifications[]` and `unreadCount` and caps list to 50 |  | PENDING |
| NOTIF_BE_TC_002 | Notifications & Reminders | Backend (Django) | Positive | Filter notifications by type/is_read | 1. Authenticate<br/>2. GET `/api/notifications/?type=friend_request&is_read=false` | Query params | 200 OK<br/>Only matching notifications returned |  | PENDING |
| NOTIF_BE_TC_003 | Notifications & Reminders | Backend (Django) | Positive | Unread count endpoint | 1. Authenticate<br/>2. GET `/api/notifications/unread/` | None | 200 OK<br/>Count equals non-read and non-dismissed notifications |  | PENDING |
| NOTIF_BE_TC_004 | Notifications & Reminders | Backend (Django) | Positive | Mark one notification read | 1. Authenticate<br/>2. POST `/api/notifications/{id}/mark-read/` | Notification id | 200 OK<br/>Status becomes `read` and read timestamp is recorded |  | PENDING |
| NOTIF_BE_TC_005 | Notifications & Reminders | Backend (Django) | Positive | Mark all notifications read | 1. Authenticate<br/>2. POST `/api/notifications/mark-all-read/` | None | 200 OK<br/>Returns updated count; unreadCount becomes 0 (except dismissed logic) |  | PENDING |
| NOTIF_BE_TC_006 | Notifications & Reminders | Backend (Django) | Positive | Snooze notification default behavior | 1. Authenticate<br/>2. POST `/api/notifications/{id}/snooze/` without minutes | None | 200 OK<br/>Notification snoozed for default minutes (30) |  | PENDING |
| NOTIF_BE_TC_007 | Notifications & Reminders | Backend (Django) | Edge | Snooze boundary values | 1. Authenticate<br/>2. POST snooze with `minutes=-5` and `minutes=100000` | Boundary minutes | 400 BAD REQUEST (preferred) or safe clamping; no 500 error |  | PENDING |
| NOTIF_BE_TC_008 | Notifications & Reminders | Backend (Django) | Positive | Dismiss notification removes from active inbox | 1. Authenticate<br/>2. POST `/api/notifications/{id}/dismiss/`<br/>3. GET list | Notification id | 200 OK<br/>Dismissed notification is excluded from unread count and optionally from list |  | PENDING |
| NOTIF_BE_TC_009 | Notifications & Reminders | Backend (Django) | Positive | Notification settings update persists | 1. Authenticate<br/>2. GET `/api/notification-settings/`<br/>3. PATCH settings to disable reminders | Example flags | 200 OK<br/>Subsequent GET reflects updated settings |  | PENDING |
| NOTIF_BE_TC_010 | Notifications & Reminders | Backend (Django) | Positive | Habit reminder create and list | 1. Authenticate<br/>2. POST `/api/habit-reminders/` with habit+schedule<br/>3. GET `/api/habit-reminders/` | habit_id, time, days | 201 CREATED on create<br/>List includes new reminder scoped to user |  | PENDING |

---

## 6.2 Frontend Tests

| Test Case ID | Module Name | Component | Type | Test Scenario | Test Steps | Test Data | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|---|---|---|---|
| NOTIF_FE_TC_001 | Notifications & Reminders | Frontend (Flutter) | Positive | Notifications inbox renders and badge count displays | 1. Open notifications screen<br/>2. Verify list items and unread badge | Mock notifications | Unread items visually distinct; badge equals unreadCount |  | PENDING |
| NOTIF_FE_TC_002 | Notifications & Reminders | Frontend (Flutter) | Positive | Mark as read updates UI | 1. Open a notification<br/>2. Verify it becomes read and badge decreases | Unread item | UI updates without full reload; item style changes |  | PENDING |
| NOTIF_FE_TC_003 | Notifications & Reminders | Frontend (Flutter) | Negative | Notifications API failure shows retry UX | 1. Mock 500 on list call<br/>2. Open screen | 500 | Error widget and retry button; no crash |  | PENDING |
| NOTIF_FE_TC_004 | Notifications & Reminders | Frontend (Flutter) | Positive | Reminder creation validates inputs | 1. Open reminder creation<br/>2. Select time and recurrence<br/>3. Save | Valid schedule | Save calls backend, success toast, reminder appears in list |  | PENDING |
| NOTIF_FE_TC_005 | Notifications & Reminders | Frontend (Flutter) | Edge | OS notification permission denied handling | 1. Deny notification permission<br/>2. Enable reminders | Permission denied | UI shows guidance; toggles revert; no crash |  | PENDING |
| NOTIF_FE_TC_006 | Notifications & Reminders | Frontend (Flutter) | Positive | Snooze from notification item | 1. Tap snooze action<br/>2. Choose duration | 30 minutes | Item marked snoozed/removed; action confirmation shown |  | PENDING |
| NOTIF_FE_TC_007 | Notifications & Reminders | Frontend (Flutter) | Edge | Timezone display consistency for reminders | 1. Change device timezone<br/>2. View reminder times | Different TZ | Times shown in device locale consistently |  | PENDING |
| NOTIF_FE_TC_008 | Notifications & Reminders | Frontend (Flutter) | Positive | Smart tips interactions persist | 1. Open smart tips<br/>2. Like/save/dismiss tip | Tip item | UI state persists after refresh and matches backend |  | PENDING |

---

# MODULE 7: GAMIFICATION (XP, BADGES, CHALLENGES)

## 7.1 Backend Tests

| Test Case ID | Module Name | Component | Type | Test Scenario | Test Steps | Test Data | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|---|---|---|---|
| GAME_BE_TC_001 | Gamification (XP, Badges, Challenges) | Backend (Django) | Positive | Gamification dashboard endpoint | 1. Authenticate<br/>2. GET `/api/gamification/` | User with XP/coins | 200 OK<br/>Payload includes XP, level, wallet/coins, streak/freezes, and active challenges |  | PENDING |
| GAME_BE_TC_002 | Gamification (XP, Badges, Challenges) | Backend (Django) | Positive | Claim daily login bonus (first claim today) | 1. Authenticate<br/>2. POST `/api/gamification/claim-login/` | None | 200 OK<br/>Bonus applied once; response indicates claimed |  | PENDING |
| GAME_BE_TC_003 | Gamification (XP, Badges, Challenges) | Backend (Django) | Edge | Claim daily login bonus idempotent | 1. Claim once today<br/>2. Claim again | Same day | 200 OK<br/>Second call returns already-claimed state without double award |  | PENDING |
| GAME_BE_TC_004 | Gamification (XP, Badges, Challenges) | Backend (Django) | Positive | Wallet endpoint returns balance and transactions | 1. Authenticate<br/>2. GET `/api/gamification/wallet/` | None | 200 OK<br/>Wallet exists; transactions list returned (<=20) |  | PENDING |
| GAME_BE_TC_005 | Gamification (XP, Badges, Challenges) | Backend (Django) | Edge | XP history limit is capped at 100 | 1. Authenticate<br/>2. GET `/api/gamification/xp-history/?limit=500` | limit=500 | 200 OK<br/>Events returned <= 100 |  | PENDING |
| GAME_BE_TC_006 | Gamification (XP, Badges, Challenges) | Backend (Django) | Negative | Buy streak freeze insufficient coins | 1. Authenticate user with insufficient balance<br/>2. POST `/api/gamification/buy-freeze/` | coins=0 | 400 BAD REQUEST<br/>Clear error message; no negative balance |  | PENDING |
| GAME_BE_TC_007 | Gamification (XP, Badges, Challenges) | Backend (Django) | Positive | List streak freezes | 1. Authenticate<br/>2. GET `/api/gamification/freezes/` | None | 200 OK<br/>Response includes available freeze tokens |  | PENDING |
| GAME_BE_TC_008 | Gamification (XP, Badges, Challenges) | Backend (Django) | Positive | Create a new challenge | 1. Authenticate<br/>2. POST `/api/gamification/challenges/create/` | Title, duration, goal | 201 CREATED<br/>Challenge returned; creator auto-joined |  | PENDING |
| GAME_BE_TC_009 | Gamification (XP, Badges, Challenges) | Backend (Django) | Negative | Join challenge invalid ID | 1. Authenticate<br/>2. POST `/api/gamification/challenges/999999/join/` | invalid id | 404 NOT FOUND |  | PENDING |
| GAME_BE_TC_010 | Gamification (XP, Badges, Challenges) | Backend (Django) | Positive | Leaderboard endpoint supports type param | 1. Authenticate<br/>2. GET `/api/gamification/leaderboard/?type=weekly` | type=weekly | 200 OK<br/>Entries sorted by score; includes rank/user/metric fields |  | PENDING |
| GAME_BE_TC_011 | Gamification (XP, Badges, Challenges) | Backend (Django) | Edge | Milestone awards are not duplicated | 1. Trigger a milestone condition<br/>2. POST `/api/gamification/check-milestones/` twice | Same state | First call awards milestone; second call returns no new awards |  | PENDING |
| GAME_BE_TC_012 | Gamification (XP, Badges, Challenges) | Backend (Django) | Negative | Seed endpoint restricted to staff | 1. Authenticate non-staff<br/>2. POST `/api/gamification/seed/` | Non-staff | 403 FORBIDDEN |  | PENDING |

---

## 7.2 Frontend Tests

| Test Case ID | Module Name | Component | Type | Test Scenario | Test Steps | Test Data | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|---|---|---|---|
| GAME_FE_TC_001 | Gamification (XP, Badges, Challenges) | Frontend (Flutter) | Positive | Gamification dashboard renders level/XP/coins | 1. Navigate to gamification screen<br/>2. Verify progress bar and wallet widgets | Mock dashboard | UI renders correctly; values formatted; no overflow |  | PENDING |
| GAME_FE_TC_002 | Gamification (XP, Badges, Challenges) | Frontend (Flutter) | Positive | Claim daily bonus shows correct states | 1. Tap claim bonus button<br/>2. Mock claimed response | Claimed | Button disables while loading; success message shown; UI updates to claimed state |  | PENDING |
| GAME_FE_TC_003 | Gamification (XP, Badges, Challenges) | Frontend (Flutter) | Edge | Already-claimed response does not double animate | 1. Mock already-claimed response<br/>2. Tap claim | already_claimed | UI shows “Already claimed” state without changing balances |  | PENDING |
| GAME_FE_TC_004 | Gamification (XP, Badges, Challenges) | Frontend (Flutter) | Negative | Buy freeze insufficient coins shows error | 1. Tap buy freeze<br/>2. Mock 400 error | 400 | Error message displayed; no state corruption |  | PENDING |
| GAME_FE_TC_005 | Gamification (XP, Badges, Challenges) | Frontend (Flutter) | Positive | Challenge creation form validation | 1. Open create challenge<br/>2. Submit empty fields<br/>3. Submit valid fields | Challenge form | Client validation blocks invalid submit; valid creates and appears in list |  | PENDING |
| GAME_FE_TC_006 | Gamification (XP, Badges, Challenges) | Frontend (Flutter) | Positive | Leaderboard view switches weekly/monthly | 1. Open leaderboard<br/>2. Switch type filter | Switch | List refreshes and ranks update without UI glitch |  | PENDING |
| GAME_FE_TC_007 | Gamification (XP, Badges, Challenges) | Frontend (Flutter) | Negative | Gamification API error state | 1. Mock 500 on dashboard<br/>2. Render screen | 500 | Error UI and retry button shown |  | PENDING |
| GAME_FE_TC_008 | Gamification (XP, Badges, Challenges) | Frontend (Flutter) | Edge | XP history list performance | 1. Open XP history<br/>2. Render many events (mock) | Many events | Smooth scroll; items render correctly; truncation consistent with API |  | PENDING |

---

# MODULE 8: COMMUNITY & LEADERBOARD

## 8.1 Backend Tests

| Test Case ID | Module Name | Component | Type | Test Scenario | Test Steps | Test Data | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|---|---|---|---|
| COMM_BE_TC_001 | Community & Leaderboard | Backend (Django) | Positive | Feed list pagination and server cap on limit | 1. Authenticate<br/>2. GET `/api/social/feed/?page=1&limit=100` | limit=100 | 200 OK<br/>Server caps results to max 50 per page (per implementation)<br/>Response includes `success`, `page`, `results[]` |  | PENDING |
| COMM_BE_TC_002 | Community & Leaderboard | Backend (Django) | Negative | Create feed post requires content | 1. Authenticate<br/>2. POST `/api/social/feed/` with empty content | content="" | 400 BAD REQUEST<br/>Message indicates content required |  | PENDING |
| COMM_BE_TC_003 | Community & Leaderboard | Backend (Django) | Positive | Create motivation post | 1. Authenticate<br/>2. POST `/api/social/feed/` with content + postType | postType=motivation | 201 CREATED<br/>Post stored and returned with author fields |  | PENDING |
| COMM_BE_TC_004 | Community & Leaderboard | Backend (Django) | Positive | Like toggles and updates denormalized count | 1. Authenticate as user A<br/>2. POST `/api/social/feed/{post_id}/like/`<br/>3. POST again to unlike | Post by user B | Like: `liked=true`, `likeCount` increments<br/>Unlike: `liked=false`, `likeCount` decrements (min 0)<br/>Notification sent to author when liking others |  | PENDING |
| COMM_BE_TC_005 | Community & Leaderboard | Backend (Django) | Positive | Comments list + add comment | 1. Authenticate<br/>2. GET `/api/social/feed/{post_id}/comments/`<br/>3. POST comment with content | content="Nice!" | GET: 200 OK chronological list<br/>POST: 201 CREATED and post.comment_count increments |  | PENDING |
| COMM_BE_TC_006 | Community & Leaderboard | Backend (Django) | Negative | Comment requires non-empty content | 1. Authenticate<br/>2. POST empty comment | content="" | 400 BAD REQUEST |  | PENDING |
| COMM_BE_TC_007 | Community & Leaderboard | Backend (Django) | Edge | Friend search min query length (q<2) | 1. Authenticate<br/>2. GET `/api/social/friends/search/?q=a`<br/>3. GET with `q=jo` | q length 1 vs 2 | q<2 returns empty users list<br/>q>=2 returns up to 20 matches excluding self |  | PENDING |
| COMM_BE_TC_008 | Community & Leaderboard | Backend (Django) | Positive | Send friend request creates pending friendship + notification | 1. Authenticate user A<br/>2. POST `/api/social/friends/send-request/` | to_user_id=2 | 200 OK<br/>Friendship created pending; notification created for recipient |  | PENDING |
| COMM_BE_TC_009 | Community & Leaderboard | Backend (Django) | Edge | Duplicate friend request does not create duplicates | 1. Send request A→B twice | Existing pending | 400 or idempotent success; exactly one Friendship row remains |  | PENDING |
| COMM_BE_TC_010 | Community & Leaderboard | Backend (Django) | Positive | Accept/reject friend request endpoints | 1. Recipient calls POST `/api/social/friends/accept-request/`<br/>2. Another request: POST `/api/social/friends/reject-request/` | friendshipId/fromUserId per API | 200 OK<br/>Status updated to accepted/rejected<br/>Acceptance triggers "friend_accepted" notification to sender |  | PENDING |
| COMM_BE_TC_011 | Community & Leaderboard | Backend (Django) | Positive | Remove friend endpoint | 1. Authenticate<br/>2. POST `/api/social/friends/remove/` | friend user id | 200 OK<br/>Friendship removed or deactivated; no longer appears in friends list |  | PENDING |
| COMM_BE_TC_012 | Community & Leaderboard | Backend (Django) | Negative | Social endpoints require auth | 1. GET `/api/social/feed/` without token | No token | 401 UNAUTHORIZED |  | PENDING |

---

## 8.2 Frontend Tests

| Test Case ID | Module Name | Component | Type | Test Scenario | Test Steps | Test Data | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|---|---|---|---|
| COMM_FE_TC_001 | Community & Leaderboard | Frontend (Flutter) | Positive | Feed renders and paginates smoothly | 1. Open community feed<br/>2. Scroll to load next page | Mock feed | Posts render with author, time, content; infinite scroll loads more without duplicates |  | PENDING |
| COMM_FE_TC_002 | Community & Leaderboard | Frontend (Flutter) | Positive | Create post validation and submission | 1. Open create post UI<br/>2. Submit empty content<br/>3. Submit valid content | Content | Validation error for empty; success adds post to feed top |  | PENDING |
| COMM_FE_TC_003 | Community & Leaderboard | Frontend (Flutter) | Positive | Like/unlike updates count and state | 1. Tap like icon<br/>2. Tap again | N/A | Icon toggles; count updates; state persists after refresh |  | PENDING |
| COMM_FE_TC_004 | Community & Leaderboard | Frontend (Flutter) | Positive | Commenting workflow | 1. Open comments screen<br/>2. Add comment<br/>3. Verify it appears | Comment | Comment appears and count updates without full reload |  | PENDING |
| COMM_FE_TC_005 | Community & Leaderboard | Frontend (Flutter) | Edge | Offline social interactions show safe errors | 1. Disable network<br/>2. Like/comment | Offline | Error displayed; UI does not show false success; retry possible |  | PENDING |
| COMM_FE_TC_006 | Community & Leaderboard | Frontend (Flutter) | Positive | Friend search and relationship status badges | 1. Open friends search<br/>2. Enter 1 char then 2+ chars | Query length | No results for 1 char; results for 2+ with status (none/pending/accepted/incoming) |  | PENDING |
| COMM_FE_TC_007 | Community & Leaderboard | Frontend (Flutter) | Positive | Send/accept friend request UI states | 1. Send request from account A<br/>2. Accept from account B | Two accounts | Button changes to Pending then Accepted; friend appears in list |  | PENDING |
| COMM_FE_TC_008 | Community & Leaderboard | Frontend (Flutter) | Negative | Feed API failure shows retry UI | 1. Mock 500 on feed call<br/>2. Open feed | 500 | Error state + retry; no crash |  | PENDING |

---

# APPENDIX: TEST DATA SETS

## A.1 Standard User Accounts

| Dataset ID | Description | Fields / Values |
|---|---|---|
| DATA_USER_001 | Standard email user | email="student1@example.com", name="Student One", password="SecurePass123!@#", auth_provider="email" |
| DATA_USER_002 | Google OAuth user | email="google.user@example.com", name="Google User", google_id="sub_1234567890", auth_provider="google" |
| DATA_USER_003 | Power user (analytics heavy) | email="power.user@example.com", name="Power User", 15 habits, 180 logs, 5 friends |

## A.2 Habit Definitions

| Dataset ID | Description | Fields / Values |
|---|---|---|
| DATA_HABIT_001 | Simple daily habit | title="Drink Water", frequency="daily", priority="medium", reminder_time="09:00" |
| DATA_HABIT_002 | Weekly habit | title="Call Parents", frequency="weekly", weekdays=["Sun"] |
| DATA_HABIT_003 | Quantified habit | title="Read", goal="100 pages", supports partial completion |
| DATA_HABIT_004 | Paused habit | status="paused", streak preserved |

## A.3 Categories

| Dataset ID | Description | Fields / Values |
|---|---|---|
| DATA_CAT_001 | Default category | name="Fitness", icon_code=0xE52F, color_value=0xFF22C55E |
| DATA_CAT_002 | Custom category | name="Exam Prep", icon_code=0xE8EF, color_value=0xFF6366F1 |

## A.4 API Error Simulation Payloads

| Dataset ID | Purpose | Example |
|---|---|---|
| DATA_ERR_401 | Unauthorized | Missing `Authorization: Bearer <token>` header |
| DATA_ERR_400 | Validation | Missing required fields (e.g., habit title) |
| DATA_ERR_404 | Not found | Non-existent `habit_id` / `post_id` |
| DATA_ERR_500 | Server error | Force service exception; verify client resilience |
