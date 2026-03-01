"""
=============================================================================
 Custom User Manager
=============================================================================

 Module:  authentication/managers.py
 Project: DailyHabits Backend

 Purpose:
   Provides the custom object manager for the User model so that
   Django’s ``createsuperuser`` management command and all ORM
   queries use *email* (not a username) as the canonical identifier.

 Usage:
   Automatically wired to User via ``objects = UserManager()``.
   Can also be called directly:
       User.objects.create_user('a@b.com', 'Alice', 'pass1234')

 Related Modules:
   - authentication.models  → User (the model this manager serves)
=============================================================================
"""

from django.contrib.auth.models import BaseUserManager


class UserManager(BaseUserManager):
    """
    Custom Manager for the email-based User model.

    Overrides ``create_user`` and ``create_superuser`` to normalise
    the email address and enforce that both email and name are provided.
    """

    # -----------------------------------------------------------------
    #  Regular User Creation
    # -----------------------------------------------------------------
    def create_user(self, email, name, password=None, **extra_fields):
        """
        Create, persist and return a regular (non-admin) user.

        Args:
            email:    The user’s email address (will be normalised).
            name:     Full display name.
            password: Raw password — hashed via ``set_password()``.
            **extra_fields: Additional model fields (e.g. profile_image).

        Raises:
            ValueError: If email or name is missing.

        Returns:
            User: The newly created user instance.
        """
        if not email:
            raise ValueError('The Email field must be set')
        if not name:
            raise ValueError('The Name field must be set')

        # Normalise the domain part of the email to lowercase
        email = self.normalize_email(email)
        user = self.model(email=email, name=name, **extra_fields)
        user.set_password(password)       # Hash the raw password
        user.save(using=self._db)
        return user

    # -----------------------------------------------------------------
    #  Superuser Creation
    # -----------------------------------------------------------------
    def create_superuser(self, email, name, password=None, **extra_fields):
        """
        Create, persist and return a superuser (admin) account.

        Automatically sets ``is_staff``, ``is_superuser`` and
        ``is_active`` to ``True`` and validates those flags.

        Delegates to ``create_user`` after applying defaults.
        """
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)

        # Guard against accidental flag overrides
        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')

        return self.create_user(email, name, password, **extra_fields)