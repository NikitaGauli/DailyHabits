from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any, cast

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from habits.models import Category, Habit, HabitLog
from notifications.models import Notification


User = get_user_model()


class UserModelTests(TestCase):
    def test_create_user_and_str(self):
        user = cast(Any, User.objects).create_user(
            email="qa.user@example.com",
            name="QA User",
            password="StrongPassw0rd!",
        )
        self.assertTrue(user.pk)
        self.assertEqual(str(user), "qa.user@example.com")
        self.assertEqual(user.get_full_name(), "QA User")
        self.assertEqual(user.get_short_name(), "QA")

    def test_email_is_unique(self):
        cast(Any, User.objects).create_user(
            email="unique@example.com",
            name="One",
            password="StrongPassw0rd!",
        )
        with self.assertRaises(Exception):
            cast(Any, User.objects).create_user(
                email="unique@example.com",
                name="Two",
                password="StrongPassw0rd!",
            )


class HabitModelTests(TestCase):
    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="habits.tester@example.com",
            name="Habits Tester",
            password="StrongPassw0rd!",
        )

    def test_category_str_and_unique_name(self):
        cat = Category.objects.create(name="Health", description="Health habits")
        self.assertEqual(str(cat), "Health")

        with self.assertRaises(Exception):
            Category.objects.create(name="Health")

    def test_habit_str_and_soft_delete(self):
        habit = Habit.objects.create(
            user=self.user,
            title="Drink Water",
            description="8 glasses",
            category_name="Health",
            frequency="daily",
        )
        self.assertIn("Drink Water", str(habit))
        self.assertFalse(habit.is_deleted)

        habit.soft_delete()
        habit.refresh_from_db()
        self.assertTrue(habit.is_deleted)
        self.assertIsNotNone(habit.deleted_at)

    def test_habitlog_creation(self):
        habit = Habit.objects.create(
            user=self.user,
            title="Read",
            category_name="Learning",
            frequency="daily",
        )
        log = HabitLog.objects.create(
            habit=habit,
            date=timezone.now().date(),
            status="completed",
            count=1,
        )
        self.assertTrue(log.pk)
        log_any = cast(Any, log)
        self.assertEqual(log_any.habit_id, habit.id)
        self.assertEqual(log.status, "completed")


class NotificationModelTests(TestCase):
    def setUp(self):
        self.user = cast(Any, User.objects).create_user(
            email="notify.tester@example.com",
            name="Notify Tester",
            password="StrongPassw0rd!",
        )

    def test_mark_as_read_sets_status_and_timestamp(self):
        n = Notification.objects.create(
            user=self.user,
            notification_type="system",
            title="Test",
            message="Hello",
            status="sent",
        )
        self.assertFalse(n.is_read)
        self.assertIsNone(n.read_at)

        n.mark_as_read()
        n.refresh_from_db()
        self.assertTrue(n.is_read)
        self.assertIsNotNone(n.read_at)

    def test_snooze_sets_until_and_status(self):
        n = Notification.objects.create(
            user=self.user,
            notification_type="reminder",
            title="Reminder",
            message="Do it",
            status="sent",
        )
        before = timezone.now()
        n.snooze(minutes=15)
        n.refresh_from_db()

        self.assertEqual(n.status, "snoozed")
        self.assertIsNotNone(n.snooze_until)
        snooze_until = cast(datetime, n.snooze_until)
        self.assertGreaterEqual(snooze_until, before + timedelta(minutes=14))
