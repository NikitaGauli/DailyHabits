"""
=============================================================================
 Authentication Serializers
=============================================================================

 Module:  authentication/serializers.py
 Project: DailyHabits Backend

 Purpose:
   DRF serializers responsible for validating incoming request data and
   transforming User model instances into JSON-safe representations.

 Serializers Provided:
   • UserSerializer           – Read/update representation of a user.
   • RegisterSerializer       – Validates email + name + matched passwords.
   • LoginSerializer          – Validates login credentials.
   • ChangePasswordSerializer – Validates old + new password pair.

 Related Modules:
   - authentication.models → User model
   - authentication.views  → Endpoints that consume these serializers
=============================================================================
"""

from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password

# Resolve the project’s active User model (AUTH_USER_MODEL)
User = get_user_model()


# =============================================================================
#  USER SERIALIZER — Profile Representation
# =============================================================================

class UserSerializer(serializers.ModelSerializer):
    """
    Read / Update serializer for the User model.

    Exposes public profile fields and denormalized habit statistics.
    Passwords are intentionally excluded for security.
    """

    class Meta:
        model = User
        fields = [
            'id',
            'email',
            'name',
            'profile_image',
            'auth_provider',
            'created_at',
            'current_streak',
            'total_habits_completed',
        ]
        read_only_fields = ['id', 'created_at', 'auth_provider']


# =============================================================================
#  REGISTER SERIALIZER — New Account Creation
# =============================================================================

class RegisterSerializer(serializers.ModelSerializer):
    """
    Validates and creates a new user account.

    Requires ``password`` and ``password2`` (confirmation).  Both fields
    are write-only so they never appear in response payloads.  Django’s
    built-in password validators are applied to ``password``.
    """

    password = serializers.CharField(
        write_only=True,
        required=True,
        validators=[validate_password],
        style={'input_type': 'password'}
    )
    password2 = serializers.CharField(
        write_only=True,
        required=True,
        style={'input_type': 'password'}
    )

    class Meta:
        model = User
        fields = ['email', 'name', 'password', 'password2']

    def validate(self, attrs):
        """
        Cross-field validation: ensure password and confirmation match.
        """
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({
                "password": "Password fields didn't match."
            })
        return attrs

    def create(self, validated_data):
        """
        Create and return a new User instance.

        Pops the confirmation field before delegating to
        ``UserManager.create_user`` which handles password hashing.
        """
        validated_data.pop('password2')
        user = User.objects.create_user(  # type: ignore
            email=validated_data['email'],
            name=validated_data['name'],
            password=validated_data['password']
        )
        return user


# =============================================================================
#  LOGIN SERIALIZER — Credential Validation
# =============================================================================

class LoginSerializer(serializers.Serializer):
    """
    Validates login credentials (email + password).

    Does NOT perform authentication itself — that responsibility
    belongs to the LoginView.  Password is write-only.
    """

    email = serializers.EmailField(required=True)
    password = serializers.CharField(
        required=True,
        write_only=True,
        style={'input_type': 'password'}
    )


# =============================================================================
#  CHANGE PASSWORD SERIALIZER
# =============================================================================

class ChangePasswordSerializer(serializers.Serializer):
    """
    Validates a password-change request.

    Requires the user’s current password (``old_password``) for
    verification and a ``new_password`` that satisfies Django’s
    password-strength validators.
    """

    old_password = serializers.CharField(
        required=True,
        write_only=True,
        style={'input_type': 'password'}
    )
    new_password = serializers.CharField(
        required=True,
        write_only=True,
        validators=[validate_password],
        style={'input_type': 'password'}
    )


# =============================================================================
#  GOOGLE AUTH SERIALIZER — Social Login Token Validation
# =============================================================================

class GoogleAuthSerializer(serializers.Serializer):
    """
    Validates the Google ID token sent from the Flutter frontend.

    This serializer only validates the *presence* of the token string.
    Actual cryptographic verification is performed in ``GoogleAuthView``
    using Google's ``google.oauth2.id_token`` module.

    Fields:
        id_token (str): The Google ID token obtained via the
                        ``google_sign_in`` Flutter package.
    """

    id_token = serializers.CharField(
        required=True,
        help_text='Google ID token from the frontend Google Sign-In SDK.',
    )


# =============================================================================
#  FORGOT PASSWORD SERIALIZER — Email Submission
# =============================================================================

class ForgotPasswordSerializer(serializers.Serializer):
    """
    Validates the email address submitted for a password-reset request.

    Only checks format — does NOT reveal whether the email exists in the
    database.  The view always returns a generic success message.
    """

    email = serializers.EmailField(
        required=True,
        help_text='The email address associated with your account.',
    )

    def validate_email(self, value: str) -> str:
        """Normalize the email to lowercase for consistent lookups."""
        return value.lower().strip()


# =============================================================================
#  RESET PASSWORD SERIALIZER — Token + New Password
# =============================================================================

class ResetPasswordSerializer(serializers.Serializer):
    """
    Validates the reset token and the new password pair.

    ``new_password`` is run through Django's password validators
    (min length, common-password check, numeric-only check, etc.).
    ``confirm_password`` must match ``new_password``.
    """

    token = serializers.CharField(
        required=True,
        min_length=64,
        max_length=64,
        help_text='The 64-character hex reset token from the email link.',
    )
    new_password = serializers.CharField(
        required=True,
        write_only=True,
        validators=[validate_password],
        style={'input_type': 'password'},
        help_text='Must satisfy Django password validators (≥8 chars, not common, etc.).',
    )
    confirm_password = serializers.CharField(
        required=True,
        write_only=True,
        style={'input_type': 'password'},
    )

    def validate(self, attrs):
        """Ensure new_password and confirm_password match."""
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError({
                'confirm_password': 'Passwords do not match.',
            })
        return attrs


# =============================================================================
#  VALIDATE RESET TOKEN SERIALIZER — Pre-flight Check
# =============================================================================

class ValidateResetTokenSerializer(serializers.Serializer):
    """
    Validates the token format for the optional pre-flight check.
    """

    token = serializers.CharField(
        required=True,
        min_length=64,
        max_length=64,
        help_text='The 64-character hex reset token.',
    )


# =============================================================================
#  REQUEST OTP SERIALIZER — Email for OTP Delivery
# =============================================================================

class RequestOTPSerializer(serializers.Serializer):
    """
    Validates the email address submitted for an OTP-based password reset.

    Only checks format — does NOT reveal whether the email exists.
    The view always returns a generic success message.
    """

    email = serializers.EmailField(
        required=True,
        help_text='The email address associated with your account.',
    )

    def validate_email(self, value: str) -> str:
        """Normalize to lowercase for consistent lookups."""
        return value.lower().strip()


# =============================================================================
#  RESET PASSWORD WITH OTP SERIALIZER — OTP + New Password
# =============================================================================

class ResetPasswordWithOTPSerializer(serializers.Serializer):
    """
    Validates the 6-digit OTP and the new password pair.

    ``new_password`` is run through Django's password validators.
    ``confirm_password`` must match ``new_password``.
    """

    email = serializers.EmailField(
        required=True,
        help_text='The email address the OTP was sent to.',
    )
    otp = serializers.CharField(
        required=True,
        min_length=6,
        max_length=6,
        help_text='The 6-digit OTP from the email.',
    )
    new_password = serializers.CharField(
        required=True,
        write_only=True,
        validators=[validate_password],
        style={'input_type': 'password'},
        help_text='Must satisfy Django password validators (≥8 chars, not common, etc.).',
    )
    confirm_password = serializers.CharField(
        required=True,
        write_only=True,
        style={'input_type': 'password'},
    )

    def validate_email(self, value: str) -> str:
        """Normalize to lowercase."""
        return value.lower().strip()

    def validate_otp(self, value: str) -> str:
        """Ensure the OTP contains only digits."""
        if not value.isdigit():
            raise serializers.ValidationError('OTP must contain only digits.')
        return value

    def validate(self, attrs):
        """Ensure new_password and confirm_password match."""
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError({
                'confirm_password': 'Passwords do not match.',
            })
        return attrs