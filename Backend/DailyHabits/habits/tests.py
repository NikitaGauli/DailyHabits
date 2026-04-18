from datetime import timedelta

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from habits.models import Habit, HabitLog, Streak


class HabitLifecycleAndReflectionTests(APITestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            email='habit-tests@example.com',
            name='Habit Tester',
            password='StrongPass123!'
        )
        self.client.force_authenticate(user=self.user)
        self.habit = Habit.objects.create(
            user=self.user,
            title='Read for 20 minutes',
            category_name='Learning',
            frequency='daily',
            status='active',
        )
        Streak.objects.get_or_create(habit=self.habit)

    def test_archive_and_unarchive_flow(self):
        archive_url = f'/api/habits/{self.habit.id}/archive/'
        unarchive_url = f'/api/habits/{self.habit.id}/unarchive/'

        archive_response = self.client.post(archive_url, {'reason': 'Completed current goal'}, format='json')
        self.assertEqual(archive_response.status_code, status.HTTP_200_OK)

        self.habit.refresh_from_db()
        self.assertEqual(self.habit.status, 'archived')

        archived_list = self.client.get('/api/habits/archived/')
        self.assertEqual(archived_list.status_code, status.HTTP_200_OK)
        self.assertEqual(archived_list.data['count'], 1)

        unarchive_response = self.client.post(unarchive_url, {}, format='json')
        self.assertEqual(unarchive_response.status_code, status.HTTP_200_OK)

        self.habit.refresh_from_db()
        self.assertEqual(self.habit.status, 'active')

    def test_toggle_complete_accepts_optional_reflection_fields(self):
        toggle_url = f'/api/habits/{self.habit.id}/toggle-complete/'
        payload = {
            'notes': 'Felt focused and calm today.',
            'moodRating': 5,
            'energyLevel': 4,
            'count': 1,
        }

        response = self.client.post(toggle_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        today = timezone.now().date()
        log = HabitLog.objects.get(habit=self.habit, date=today)
        self.assertEqual(log.status, 'completed')
        self.assertEqual(log.notes, payload['notes'])
        self.assertEqual(log.mood_rating, payload['moodRating'])
        self.assertEqual(log.energy_level, payload['energyLevel'])

    def test_mark_missed_creates_log_and_summary(self):
        target_date_obj = timezone.now().date() - timedelta(days=1)
        target_date = target_date_obj.isoformat()
        mark_url = f'/api/habits/{self.habit.id}/mark-missed/'

        response = self.client.post(mark_url, {'date': target_date, 'notes': 'Busy travel day'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        log = HabitLog.objects.get(habit=self.habit, date=target_date_obj)
        self.assertEqual(log.status, 'missed')

        summary = self.client.get('/api/habits/missed-days/?days=7')
        self.assertEqual(summary.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(summary.data['totalMissed'], 1)
