"""
=============================================================================
 Authentication Views — Registration, Login, Google OAuth, Profile & GDPR
=============================================================================

 Module:  authentication/views.py
 Project: DailyHabits Backend

 Purpose:
   Implements all HTTP endpoints for the authentication lifecycle:
   • RegisterView       – POST  /api/auth/register/
   • LoginView           – POST  /api/auth/login/
   • GoogleAuthView      – POST  /api/auth/google/
   • LogoutView          – POST  /api/auth/logout/
   • UserProfileView     – GET | PUT  /api/auth/profile/
   • ChangePasswordView  – POST  /api/auth/change-password/
   • LoginHistoryView    – GET   /api/auth/login-history/
   • DataExportView      – GET   /api/auth/data-export/
   • DataDeletionRequestView – GET | POST  /api/auth/request-deletion/

 Security:
   - JWT tokens (access + refresh) are issued on register / login / google.
   - Google ID tokens are verified against Google's public keys.
   - Refresh tokens are blacklisted on logout.
   - All authenticated endpoints require ``IsAuthenticated`` permission.

 Related Modules:
   - authentication.serializers  → Input validation
   - authentication.models       → User, LoginActivity, DataDeletionRequest
============================================================================="""

from __future__ import annotations

import logging
from typing import Any, TYPE_CHECKING

from django.conf import settings
from django.contrib.auth import authenticate, get_user_model

if TYPE_CHECKING:
    from authentication.models import User as UserType
from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.tokens import RefreshToken

# Google ID token verification
from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests

from .serializers import (
    RegisterSerializer,
    LoginSerializer,
    UserSerializer,
    ChangePasswordSerializer,
    GoogleAuthSerializer,
    ForgotPasswordSerializer,
    ResetPasswordSerializer,
    ValidateResetTokenSerializer,
    RequestOTPSerializer,
    ResetPasswordWithOTPSerializer,
)
from .models import LoginActivity, DataDeletionRequest
from .password_reset_service import PasswordResetService
from .otp_service import OTPResetService

logger = logging.getLogger(__name__)

# Resolve the project’s active User model
User = get_user_model()



# =============================================================================
#  REGISTRATION
# =============================================================================

class RegisterView(generics.CreateAPIView):
    """
    POST /api/auth/register/

    Create a new user account and return JWT tokens.

    Request Body:
        email, name, password, password2

    Response (201):
        { success, message, user, token, refresh }
    """
    queryset = User.objects.all()
    permission_classes = [AllowAny]
    serializer_class = RegisterSerializer
    
    def create(self, request, *args, **kwargs):
        """Validate registration data, create the user and issue JWT tokens."""
        serializer = self.get_serializer(data=request.data)

        if serializer.is_valid():
            user = serializer.save()

            # Generate JWT access + refresh token pair
            refresh = RefreshToken.for_user(user)
            
            return Response({
                'success': True,
                'message': 'User registered successfully',
                'user': UserSerializer(user).data,
                'token': str(refresh.access_token),
                'refresh': str(refresh),
            }, status=status.HTTP_201_CREATED)
        
        return Response({
            'success': False,
            'message': 'Registration failed',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


# =============================================================================
#  LOGIN
# =============================================================================

class LoginView(APIView):
    """
    POST /api/auth/login/

    Authenticate with email + password, record the login attempt
    (for the security audit trail), and issue JWT tokens on success.
    """
    permission_classes = [AllowAny]
    
    def post(self, request):
        """Validate credentials, authenticate and return tokens."""
        serializer = LoginSerializer(data=request.data)
        
        if serializer.is_valid():
            data: dict[str, Any] = serializer.validated_data  # type: ignore[assignment]
            if data is None:
                return Response({
                    'success': False,
                    'message': 'Invalid data',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
            email = data.get('email')
            password = data.get('password')
            
            # Authenticate against the database
            user = authenticate(request, email=email, password=password)
            
            if user is not None:
                # Record successful login
                self._record_login(request, user, success=True)
                
                # Generate JWT tokens
                refresh = RefreshToken.for_user(user)
                
                return Response({
                    'success': True,
                    'message': 'Login successful',
                    'user': UserSerializer(user).data,
                    'token': str(refresh.access_token),
                    'refresh': str(refresh),
                }, status=status.HTTP_200_OK)
            else:
                # Record failed login attempt
                try:
                    failed_user = User.objects.get(email=email)
                    self._record_login(request, failed_user, success=False)
                except User.DoesNotExist:
                    pass
                
                return Response({
                    'success': False,
                    'message': 'Invalid email or password'
                }, status=status.HTTP_401_UNAUTHORIZED)
        
        return Response({
            'success': False,
            'message': 'Invalid data',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
    
    @staticmethod
    def _record_login(request, user, success=True):
        """
        Persist a LoginActivity record for security auditing.

        Extracts the client’s IP (respects X-Forwarded-For behind
        proxies), user-agent string, and a simple mobile/desktop
        device classification.
        """
        # Resolve real IP from proxy headers
        ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', ''))
        if ',' in ip:
            ip = ip.split(',')[0].strip()
        user_agent = request.META.get('HTTP_USER_AGENT', '')
        device = 'mobile' if any(k in user_agent.lower() for k in ['mobile', 'android', 'iphone']) else 'desktop'
        LoginActivity.objects.create(
            user=user,
            ip_address=ip or None,
            user_agent=user_agent[:500],
            device_type=device,
            was_successful=success,
        )


# =============================================================================
#  LOGOUT
# =============================================================================

class LogoutView(APIView):
    """
    POST /api/auth/logout/

    Blacklist the refresh token so it cannot be reused.  The access
    token will naturally expire after its TTL (defined in settings).
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        """Blacklist the supplied refresh token."""
        try:
            refresh_token = request.data.get('refresh')
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()     # Add to the blacklist table
            
            return Response({
                'success': True,
                'message': 'Logout successful'
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({
                'success': False,
                'message': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)


# =============================================================================
#  USER PROFILE
# =============================================================================

class UserProfileView(generics.RetrieveUpdateAPIView):
    """
    GET  /api/auth/profile/  — Retrieve the authenticated user’s profile.
    PUT  /api/auth/profile/  — Update profile fields (name, profile_image).

    Always scoped to ``request.user`` — users cannot access other profiles.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = UserSerializer
    
    def get_object(self):
        """Return the currently authenticated user."""
        return self.request.user

    def retrieve(self, request, *args, **kwargs):
        """Return serialized profile data wrapped in a success envelope."""
        user = self.get_object()
        serializer = self.get_serializer(user)
        
        return Response({
            'success': True,
            'user': serializer.data
        }, status=status.HTTP_200_OK)
    
    def update(self, request, *args, **kwargs):
        """Partially or fully update the user’s profile."""
        partial = kwargs.pop('partial', False)
        user = self.get_object()
        serializer = self.get_serializer(user, data=request.data, partial=partial)
        
        if serializer.is_valid():
            serializer.save()
            return Response({
                'success': True,
                'message': 'Profile updated successfully',
                'user': serializer.data
            }, status=status.HTTP_200_OK)
        
        return Response({
            'success': False,
            'message': 'Update failed',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


# =============================================================================
#  CHANGE PASSWORD
# =============================================================================

class ChangePasswordView(APIView):
    """
    POST /api/auth/change-password/

    Allows an authenticated user to update their password by
    providing the current (old) password for verification.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        """Verify old password, then set new password."""
        serializer = ChangePasswordSerializer(data=request.data)
        
        if serializer.is_valid():
            user = request.user
            data: dict[str, Any] = serializer.validated_data  # type: ignore[assignment]
            assert data is not None
            
            # Verify the user knows their current password
            if not user.check_password(data.get('old_password')):
                return Response({
                    'success': False,
                    'message': 'Old password is incorrect'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Apply and persist the new password (hashed automatically)
            user.set_password(data.get('new_password'))
            user.save()
            
            return Response({
                'success': True,
                'message': 'Password changed successfully'
            }, status=status.HTTP_200_OK)
        
        return Response({
            'success': False,
            'message': 'Invalid data',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


# =============================================================================
#  GOOGLE AUTHENTICATION — Continue with Google (Social Login)
# =============================================================================

class GoogleAuthView(APIView):
    """
    Google Authentication API View

    POST /api/auth/google/

    This view verifies the Google ID token sent from the Flutter frontend.
    If valid:
    - It retrieves user information (email, name, profile image)
    - Creates a new user if one does not exist (with an unusable password)
    - Links Google to an existing email/password account automatically
    - Returns JWT access and refresh tokens for the authenticated user

    Account Linking Strategy:
    ─────────────────────────
    1. **First, try to find user by `google_id`** (stable, never changes).
    2. **Fall back to email lookup** — handles the case where a user
       registered with email/password and now signs in with Google.
       In this scenario, `google_id` is written to their existing account
       (automatic linking).
    3. **Create a new user** — if neither google_id nor email matches.

    Security:
    - Validates token cryptographically against Google's public keys
    - Checks the token audience (aud) matches our GOOGLE_CLIENT_ID
    - Checks the token issuer (iss) is accounts.google.com
    - Stores `google_id` (Google's `sub` claim) for reliable identity matching
    - Sets an unusable password for Google-only accounts
    - Rate-limited to 10 requests/min per IP

    Request Body:
        { "id_token": "<google_id_token_string>" }

    Response (200 — success):
        {
            "success": true,
            "message": "Google authentication successful",
            "user": { "id": 1, "email": "...", "name": "...", ... },
            "token": "<jwt_access_token>",
            "refresh": "<jwt_refresh_token>",
            "is_new_user": false,
            "account_linked": false
        }
    """

    permission_classes = [AllowAny]

    def get_throttles(self):
        """Apply anonymous rate limiting to prevent abuse."""
        from rest_framework.throttling import AnonRateThrottle

        class GoogleAuthThrottle(AnonRateThrottle):
            scope = 'google_auth'
            rate = '10/min'

        return [GoogleAuthThrottle()]

    def post(self, request):
        """
        Verify a Google ID token and authenticate the user.

        Steps:
            1. Validate the incoming request data via GoogleAuthSerializer.
            2. Verify the token using Google's public keys.
            3. Extract user information from the verified token payload.
            4. Find or create the Django user (by google_id, then email).
            5. Handle account linking for email/password → Google.
            6. Record a LoginActivity entry for the security audit trail.
            7. Issue and return SimpleJWT access + refresh tokens.
        """
        serializer = GoogleAuthSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {
                    'success': False,
                    'message': 'ID token is required.',
                    'errors': serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        validated: dict[str, Any] = serializer.validated_data  # type: ignore[assignment]
        token: str = validated['id_token']

        # --- Pre-flight: Check that GOOGLE_CLIENT_ID is configured ---
        google_client_id = getattr(settings, 'GOOGLE_CLIENT_ID', '')
        if not google_client_id or google_client_id.startswith('your-'):
            logger.error(
                'GOOGLE_CLIENT_ID is not configured in settings / .env. '
                'Google authentication cannot proceed.'
            )
            return Response(
                {
                    'success': False,
                    'message': 'Google authentication is not configured on the server.',
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        # --- Step 1: Verify the Google ID token ---
        try:
            id_info = google_id_token.verify_oauth2_token(
                token,
                google_requests.Request(),
                audience=google_client_id,
            )
        except ValueError as e:
            logger.warning('Google token verification failed: %s', e)
            return Response(
                {
                    'success': False,
                    'message': 'Invalid Google token. Please try again.',
                },
                status=status.HTTP_401_UNAUTHORIZED,
            )
        except Exception as e:
            logger.error('Google token verification error: %s', e)
            return Response(
                {
                    'success': False,
                    'message': 'Could not verify Google token. Please try again later.',
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )

        # --- Step 2: Validate issuer ---
        issuer = id_info.get('iss', '')
        if issuer not in ('accounts.google.com', 'https://accounts.google.com'):
            logger.warning('Invalid Google token issuer: %s', issuer)
            return Response(
                {
                    'success': False,
                    'message': 'Invalid token issuer.',
                },
                status=status.HTTP_401_UNAUTHORIZED,
            )

        # --- Step 3: Extract user info from the verified payload ---
        email: str | None = id_info.get('email')
        name: str = id_info.get('name', '')
        google_id: str = id_info.get('sub', '')  # Stable Google user identifier
        picture: str = id_info.get('picture', '')  # Google profile picture URL

        if not email:
            return Response(
                {
                    'success': False,
                    'message': 'Google account does not have an email address.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not google_id:
            logger.warning('Google token missing sub claim for %s', email)
            return Response(
                {
                    'success': False,
                    'message': 'Google token is missing the user identifier.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # --- Step 4: Find or create user (google_id → email → create) ---
        user: UserType | None = None
        created = False
        account_linked = False

        # 4a: Try to find by google_id first (most reliable)
        try:
            user = User.objects.get(google_id=google_id)  # type: ignore[assignment]
        except User.DoesNotExist:
            pass

        # 4b: If not found by google_id, try email (handles account linking)
        if user is None:
            try:
                user = User.objects.get(email=email)  # type: ignore[assignment]
                # Email/password user signing in with Google → link account
                if not user.google_id:  # type: ignore[union-attr]
                    user.google_id = google_id  # type: ignore[union-attr]
                    update_fields = ['google_id']

                    # Optionally update profile image if not set
                    if picture and not user.profile_image:  # type: ignore[union-attr]
                        user.profile_image = picture  # type: ignore[union-attr]
                        update_fields.append('profile_image')

                    user.save(update_fields=update_fields)  # type: ignore[union-attr]
                    account_linked = True
                    logger.info(
                        'Google account linked to existing user: %s', email
                    )
            except User.DoesNotExist:
                pass

        # 4c: Create a brand-new user
        if user is None:
            user = User.objects.create(  # type: ignore[assignment]
                email=email,
                name=name or email.split('@')[0],
                google_id=google_id,
                auth_provider='google',
                profile_image=picture or None,
            )
            user.set_unusable_password()  # type: ignore[union-attr]
            user.save(update_fields=['password'])  # type: ignore[union-attr]
            created = True
            logger.info('New user created via Google OAuth: %s', email)

        # --- Step 5: Update name/picture if still missing ---
        if user is not None and not created and not account_linked:
            update_fields = []
            if not user.name and name:  # type: ignore[union-attr]
                user.name = name  # type: ignore[union-attr]
                update_fields.append('name')
            if picture and not user.profile_image:  # type: ignore[union-attr]
                user.profile_image = picture  # type: ignore[union-attr]
                update_fields.append('profile_image')
            if update_fields:
                user.save(update_fields=update_fields)  # type: ignore[union-attr]

        # --- Step 6: Record login activity ---
        LoginView._record_login(request, user, success=True)

        # --- Step 7: Issue JWT tokens ---
        assert user is not None  # guaranteed by steps 4a-4c above
        refresh = RefreshToken.for_user(user)  # type: ignore[arg-type]

        return Response(
            {
                'success': True,
                'message': 'Google authentication successful',
                'user': UserSerializer(user).data,
                'token': str(refresh.access_token),
                'refresh': str(refresh),
                'is_new_user': created,
                'account_linked': account_linked,
            },
            status=status.HTTP_200_OK,
        )


# =============================================================================
#  LOGIN HISTORY — Security Audit for End-Users
# =============================================================================

class LoginHistoryView(APIView):
    """
    GET /api/auth/login-history/

    Returns the 30 most recent login attempts (successful & failed)
    for the authenticated user, serialised with camelCase keys for
    the Flutter front-end.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        activities = LoginActivity.objects.filter(user=request.user)[:30]
        return Response({
            'success': True,
            'loginHistory': [{
                'id': a.id,
                'ipAddress': a.ip_address,
                'deviceType': a.device_type,
                'userAgent': a.user_agent[:120],
                'location': a.location,
                'loginAt': a.login_at.isoformat(),
                'wasSuccessful': a.was_successful,
            } for a in activities],
        })


# =============================================================================
#  DATA EXPORT — GDPR Data Portability
# =============================================================================

class DataExportView(APIView):
    """
    GET /api/auth/data-export/

    Returns a JSON export of all personal data (user profile, habits,
    habit logs) for GDPR data-portability compliance.  The response is
    structured so the user can save and transfer their data.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Collect user profile, habits and logs into a portable JSON export."""
        # Late imports to avoid circular dependencies between apps
        from habits.models import Habit, HabitLog
        from django.forms.models import model_to_dict

        user = request.user
        habits = Habit.objects.filter(user=user)
        logs = HabitLog.objects.filter(habit__user=user)

        return Response({
            'success': True,
            'export': {
                'user': {
                    'email': user.email,
                    'name': user.name,
                    'createdAt': user.created_at.isoformat(),
                },
                'habits': [{
                    'title': h.title,
                    'category': h.category,
                    'frequency': h.frequency,
                    'currentStreak': h.current_streak,
                    'bestStreak': h.best_streak,
                    'status': h.status,
                    'createdAt': h.created_at.isoformat(),
                } for h in habits],
                'logs': [{
                    'habitTitle': l.habit.title,
                    'completedAt': l.completed_at.isoformat() if l.completed_at else None,
                    'notes': l.notes,
                } for l in logs[:500]],
            },
        })


# =============================================================================
#  DATA DELETION REQUEST — GDPR Right to Erasure
# =============================================================================

class DataDeletionRequestView(APIView):
    """
    GET  /api/auth/request-deletion/  — Check existing deletion request status.
    POST /api/auth/request-deletion/  — Submit a new data-deletion request.

    Only one active (pending / processing) request per user is allowed.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Return the latest deletion request for the authenticated user."""
        req = DataDeletionRequest.objects.filter(user=request.user).first()
        if not req:
            return Response({'success': True, 'request': None})
        return Response({
            'success': True,
            'request': {
                'id': req.id,
                'status': req.status,
                'reason': req.reason,
                'requestedAt': req.requested_at.isoformat(),
                'processedAt': req.processed_at.isoformat() if req.processed_at else None,
            }
        })

    def post(self, request):
        """Create a new deletion request (blocks duplicates)."""
        # Prevent duplicate requests while one is already in progress
        existing = DataDeletionRequest.objects.filter(
            user=request.user, status__in=['pending', 'processing']
        ).first()
        if existing:
            return Response({
                'success': False,
                'message': 'A deletion request is already in progress.',
            }, status=status.HTTP_409_CONFLICT)
        
        DataDeletionRequest.objects.create(
            user=request.user,
            reason=request.data.get('reason', ''),
        )
        return Response({
            'success': True,
            'message': 'Deletion request submitted. Your data will be processed within 30 days.',
        }, status=status.HTTP_201_CREATED)


# =============================================================================
#  FORGOT PASSWORD — Request Reset Link
# =============================================================================

class ForgotPasswordView(APIView):
    """
    POST /api/auth/forgot-password/

    Accepts an email address and dispatches a secure reset link if the
    account exists.  Always returns a generic 200 response to prevent
    user enumeration (OWASP A01).

    Rate limiting:
      - ``PasswordResetAnonBurstThrottle`` : 5 requests / minute  (per IP)
      - ``PasswordResetAnonSustainedThrottle`` : 20 requests / hour (per IP)

    Request Body:
        { "email": "user@example.com" }

    Response (200):
        {
            "success": true,
            "message": "If an account with that email exists, a reset link has been sent."
        }
    """
    permission_classes = [AllowAny]
    throttle_classes = [
        type('PasswordResetBurst', (), {
            'scope': 'password_reset_burst',
            'rate': '5/min',
            'get_cache_key': lambda self, request, view: (
                self.get_ident(request)
            ),
            '__bases__': (),
        }),
    ]

    def get_throttles(self):
        """Apply anonymous throttles for rate limiting."""
        from rest_framework.throttling import AnonRateThrottle

        class PasswordResetBurstThrottle(AnonRateThrottle):
            scope = 'password_reset_burst'
            rate = '5/min'

        class PasswordResetSustainedThrottle(AnonRateThrottle):
            scope = 'password_reset_sustained'
            rate = '20/hour'

        return [PasswordResetBurstThrottle(), PasswordResetSustainedThrottle()]

    def post(self, request):
        """Validate email and delegate to PasswordResetService."""
        serializer = ForgotPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({
                'success': False,
                'message': 'Please provide a valid email address.',
                'errors': serializer.errors,
            }, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']  # type: ignore[index]
        result = PasswordResetService.request_reset(email=email, request=request)

        return Response(result, status=status.HTTP_200_OK)


# =============================================================================
#  VALIDATE RESET TOKEN — Optional Pre-flight Check
# =============================================================================

class ValidateResetTokenView(APIView):
    """
    POST /api/auth/validate-reset-token/

    Pre-flight check that lets the Flutter client decide whether to show
    the new-password form or an error/expired screen.

    Request Body:
        { "token": "<64-char hex token>" }

    Response (200):
        { "valid": true/false, "message": "..." }
    """
    permission_classes = [AllowAny]

    def get_throttles(self):
        from rest_framework.throttling import AnonRateThrottle

        class ValidateTokenThrottle(AnonRateThrottle):
            scope = 'validate_reset_token'
            rate = '10/min'

        return [ValidateTokenThrottle()]

    def post(self, request):
        serializer = ValidateResetTokenSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({
                'valid': False,
                'message': 'Invalid token format.',
                'errors': serializer.errors,
            }, status=status.HTTP_400_BAD_REQUEST)

        token = serializer.validated_data['token']  # type: ignore[index]
        result = PasswordResetService.validate_token(raw_token=token, request=request)

        return Response(result, status=status.HTTP_200_OK)


# =============================================================================
#  RESET PASSWORD — Consume Token & Set New Password
# =============================================================================

class ResetPasswordView(APIView):
    """
    POST /api/auth/reset-password/

    Consumes a valid reset token and sets the user's new password.
    On success, all existing sessions (refresh tokens) are invalidated
    so the user must re-authenticate on every device.

    Rate limiting:
      - 5 attempts per minute per IP.

    Request Body:
        {
            "token": "<64-char hex token>",
            "new_password": "S3cureP@ss!",
            "confirm_password": "S3cureP@ss!"
        }

    Response (200 — success):
        { "success": true, "message": "Your password has been reset..." }

    Response (400 — invalid/expired token):
        { "success": false, "message": "..." }
    """
    permission_classes = [AllowAny]

    def get_throttles(self):
        from rest_framework.throttling import AnonRateThrottle

        class ResetPasswordThrottle(AnonRateThrottle):
            scope = 'reset_password'
            rate = '5/min'

        return [ResetPasswordThrottle()]

    def post(self, request):
        serializer = ResetPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({
                'success': False,
                'message': 'Validation failed.',
                'errors': serializer.errors,
            }, status=status.HTTP_400_BAD_REQUEST)

        data: dict = serializer.validated_data  # type: ignore[assignment]
        result = PasswordResetService.reset_password(
            raw_token=data['token'],
            new_password=data['new_password'],
            request=request,
        )

        http_status = status.HTTP_200_OK if result['success'] else status.HTTP_400_BAD_REQUEST
        return Response(result, status=http_status)


# =============================================================================
#  REQUEST OTP — OTP-Based Password Reset (Step 1)
# =============================================================================

class RequestPasswordResetOTPView(APIView):
    """
    POST /api/auth/request-password-reset/

    Accepts an email address and sends a 6-digit OTP if the account exists.
    Always returns a generic 200 response to prevent user enumeration.

    Rate limiting:
      - 3 requests / minute  (per IP)
      - 10 requests / hour   (per IP)

    Request Body:
        { "email": "user@example.com" }

    Response (200):
        {
            "success": true,
            "message": "If an account with that email exists, you will receive an OTP shortly.",
            "otp_ttl_seconds": 600
        }
    """
    permission_classes = [AllowAny]

    def get_throttles(self):
        """Apply anonymous throttles for rate limiting."""
        from rest_framework.throttling import AnonRateThrottle

        class OTPRequestBurstThrottle(AnonRateThrottle):
            scope = 'otp_request_burst'
            rate = '3/min'

        class OTPRequestSustainedThrottle(AnonRateThrottle):
            scope = 'otp_request_sustained'
            rate = '10/hour'

        return [OTPRequestBurstThrottle(), OTPRequestSustainedThrottle()]

    def post(self, request):
        """Validate email and delegate to OTPResetService."""
        serializer = RequestOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({
                'success': False,
                'message': 'Please provide a valid email address.',
                'errors': serializer.errors,
            }, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']  # type: ignore[index]
        result = OTPResetService.request_otp(email=email, request=request)

        return Response(result, status=status.HTTP_200_OK)


# =============================================================================
#  VERIFY OTP & RESET PASSWORD — OTP-Based Password Reset (Step 2)
# =============================================================================

class VerifyOTPResetPasswordView(APIView):
    """
    POST /api/auth/verify-otp-reset/

    Verifies the 6-digit OTP and resets the user's password in one step.
    On success, all existing JWT sessions are invalidated.

    Rate limiting:
      - 5 attempts / minute per IP

    Request Body:
        {
            "email": "user@example.com",
            "otp": "123456",
            "new_password": "S3cureP@ss!",
            "confirm_password": "S3cureP@ss!"
        }

    Response (200 — success):
        { "success": true, "message": "Your password has been reset..." }

    Response (400 — invalid OTP / validation error):
        { "success": false, "message": "...", "attempts_remaining": 3 }
    """
    permission_classes = [AllowAny]

    def get_throttles(self):
        from rest_framework.throttling import AnonRateThrottle

        class OTPVerifyThrottle(AnonRateThrottle):
            scope = 'otp_verify'
            rate = '5/min'

        return [OTPVerifyThrottle()]

    def post(self, request):
        serializer = ResetPasswordWithOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({
                'success': False,
                'message': 'Validation failed.',
                'errors': serializer.errors,
            }, status=status.HTTP_400_BAD_REQUEST)

        data: dict = serializer.validated_data  # type: ignore[assignment]
        result = OTPResetService.verify_and_reset(
            email=data['email'],
            raw_otp=data['otp'],
            new_password=data['new_password'],
            request=request,
        )

        http_status = status.HTTP_200_OK if result['success'] else status.HTTP_400_BAD_REQUEST
        return Response(result, status=http_status)