from __future__ import annotations

from typing import Any, cast

from django.contrib.auth import get_user_model
from django.test import TestCase

from authentication.serializers import (
    RegisterSerializer,
    ForgotPasswordSerializer,
    ResetPasswordSerializer,
)
from habits.models import Habit
from habits.serializers import HabitSerializer
from notifications.models import Notification
from notifications.serializers import NotificationSerializer


User = get_user_model()


class AuthSerializerTests(TestCase):
    def test_register_serializer_rejects_password_mismatch(self):
        serializer = RegisterSerializer(
            data={
                "email": "new.user@example.com",
                "name": "New User",
                "password": "StrongPassw0rd!",
                "password2": "DifferentPassw0rd!",
            }
        )
        self.assertFalse(serializer.is_valid())
        self.assertIn("password", serializer.errors)

    def test_forgot_password_serializer_normalizes_email(self):
        serializer = ForgotPasswordSerializer(data={"email": "  USER@Example.COM "})
        self.assertTrue(serializer.is_valid())
        validated = cast(dict[str, Any], serializer.validated_data)
        self.assertEqual(validated.get("email"), "user@example.com")

    def test_reset_password_serializer_rejects_confirm_mismatch(self):
        serializer = ResetPasswordSerializer(
            data={
                "token": "a" * 64,
                "new_password": "StrongPassw0rd!",
                "confirm_password": "MismatchPassw0rd!",
            }
        )
        self.assertFalse(serializer.is_valid())
        self.assertIn("confirm_password", serializer.errors)


class HabitSerializerTests(TestCase):
    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="serializer.user@example.com",
            name="Serializer User",
            password="StrongPassw0rd!",
        )

    def test_habit_serializer_create_bootstraps_streak(self):
        serializer = HabitSerializer(
            data={
                "title": "Meditate",
                "description": "10 minutes",
                "frequency": "daily",
                "categoryName": "Mindfulness",
                "iconCode": 0xE87C,
                "colorValue": 0xFF6366F1,
            }
        )
        self.assertTrue(serializer.is_valid(), serializer.errors)
        habit = cast(Habit, serializer.save(user=self.user))

        self.assertTrue(habit.pk)
        # Streak is created in serializer.create
        self.assertTrue(hasattr(habit, "streak"))
        self.assertIsNotNone(getattr(habit, "streak", None))


class NotificationSerializerTests(TestCase):
    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="notif.serializer@example.com",
            name="Notif Serializer",
            password="StrongPassw0rd!",
        )

    def test_notification_serializer_computed_fields_null_when_missing_relations(self):
        n = Notification.objects.create(
            user=self.user,
            notification_type="system",
            title="Hello",
            message="World",
        )
        data = dict(cast(Any, NotificationSerializer(n).data))
        self.assertIsNone(data.get("fromUserName"))
        self.assertIsNone(data.get("habitTitle"))
        self.assertIsNone(data.get("groupName"))
