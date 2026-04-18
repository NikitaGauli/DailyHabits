from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from notifications.models import NotificationSettings


class NotificationSchedulingPreferenceTests(APITestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            email='notify-tests@example.com',
            name='Notify Tester',
            password='StrongPass123!'
        )
        self.client.force_authenticate(user=self.user)

    def test_settings_include_scheduling_preferences(self):
        response = self.client.get('/api/notification-settings/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        settings_payload = response.data['settings']

        self.assertIn('timezone', settings_payload)
        self.assertIn('weekendRemindersEnabled', settings_payload)
        self.assertIn('deliveryMode', settings_payload)
        self.assertIn('cooldownMinutes', settings_payload)

    def test_update_scheduling_preferences(self):
        payload = {
            'timezone': 'Asia/Kathmandu',
            'weekendRemindersEnabled': False,
            'deliveryMode': 'digest',
            'digestTime': '20:30:00',
            'reminderWindowStart': '07:00:00',
            'reminderWindowEnd': '21:00:00',
            'cooldownMinutes': 10,
        }

        response = self.client.patch('/api/notification-settings/update_settings/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        settings_obj = NotificationSettings.objects.get(user=self.user)
        self.assertEqual(settings_obj.timezone, payload['timezone'])
        self.assertEqual(settings_obj.weekend_reminders_enabled, payload['weekendRemindersEnabled'])
        self.assertEqual(settings_obj.delivery_mode, payload['deliveryMode'])
        self.assertEqual(settings_obj.cooldown_minutes, payload['cooldownMinutes'])
