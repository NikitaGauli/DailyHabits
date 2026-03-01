"""
Management command: seed_admin_roles
=====================================
Creates default admin roles with their permission sets.
Also optionally promotes a user to Super Admin.

Usage:
    python manage.py seed_admin_roles
    python manage.py seed_admin_roles --promote admin@example.com
"""

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from admin_panel.models import AdminProfile, AdminRole
from admin_panel.permissions import DEFAULT_ROLE_PERMISSIONS

User = get_user_model()

ROLE_DISPLAY_NAMES = {
    'super_admin': 'Super Admin',
    'admin': 'Admin',
    'moderator': 'Moderator',
    'support': 'Support Staff',
    'analytics': 'Analytics Viewer',
}

ROLE_DESCRIPTIONS = {
    'super_admin': 'Full platform control with 2FA requirement. Can manage all aspects of the system.',
    'admin': 'User, content, config, and gamification management. Cannot modify RBAC roles.',
    'moderator': 'Content moderation, report resolution, and user warnings.',
    'support': 'User support, ticket management, and limited user editing.',
    'analytics': 'Read-only access to analytics dashboards and data exports.',
}


class Command(BaseCommand):
    help = 'Seed default admin roles and optionally promote a user to Super Admin.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--promote',
            type=str,
            help='Email of an existing user to promote to Super Admin.',
        )

    def handle(self, *args, **options):
        created_count = 0
        updated_count = 0

        for role_key, permissions in DEFAULT_ROLE_PERMISSIONS.items():
            role, created = AdminRole.objects.update_or_create(
                name=role_key,
                defaults={
                    'display_name': ROLE_DISPLAY_NAMES[role_key],
                    'description': ROLE_DESCRIPTIONS[role_key],
                    'permissions': permissions,
                    'is_active': True,
                },
            )
            if created:
                created_count += 1
                self.stdout.write(self.style.SUCCESS(f'  ✓ Created role: {role.display_name}'))
            else:
                updated_count += 1
                self.stdout.write(f'  ↻ Updated role: {role.display_name}')

        self.stdout.write(
            self.style.SUCCESS(f'\nRoles: {created_count} created, {updated_count} updated.')
        )

        # Optionally promote a user to Super Admin
        email = options.get('promote')
        if email:
            try:
                user = User.objects.get(email=email)
            except User.DoesNotExist:
                self.stderr.write(self.style.ERROR(f'User "{email}" not found.'))
                return

            super_role = AdminRole.objects.get(name='super_admin')
            profile, created = AdminProfile.objects.update_or_create(
                user=user,
                defaults={'role': super_role, 'is_active': True},
            )
            user.is_staff = True
            user.is_superuser = True
            user.save(update_fields=['is_staff', 'is_superuser'])

            action = 'Promoted' if created else 'Updated'
            self.stdout.write(
                self.style.SUCCESS(f'{action} {email} → Super Admin ✓')
            )
