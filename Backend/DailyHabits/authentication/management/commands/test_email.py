"""
=============================================================================
 Management Command: test_email
=============================================================================

 Usage:
   python manage.py test_email                         # send to DEFAULT recipient
   python manage.py test_email --to user@example.com   # send to specific email
   python manage.py test_email --check-only            # just verify SMTP config

 Purpose:
   Verifies that the Django email backend is correctly configured by
   attempting to send a test email through the configured SMTP server.
   Useful for confirming Gmail App Password setup before relying on
   password-reset emails.
=============================================================================
"""

from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.utils import timezone


class Command(BaseCommand):
    help = 'Test email delivery by sending a verification email through the configured SMTP backend.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--to',
            type=str,
            default=None,
            help='Recipient email address. Defaults to EMAIL_HOST_USER from settings.',
        )
        parser.add_argument(
            '--check-only',
            action='store_true',
            help='Only check SMTP configuration without sending an email.',
        )

    def handle(self, *args, **options):
        self.stdout.write('\n' + '=' * 60)
        self.stdout.write('  DailyHabits — Email Configuration Test')
        self.stdout.write('=' * 60 + '\n')

        # ── Step 1: Display current configuration ──────────────────────
        backend = getattr(settings, 'EMAIL_BACKEND', 'NOT SET')
        host = getattr(settings, 'EMAIL_HOST', 'NOT SET')
        port = getattr(settings, 'EMAIL_PORT', 'NOT SET')
        use_tls = getattr(settings, 'EMAIL_USE_TLS', False)
        host_user = getattr(settings, 'EMAIL_HOST_USER', '')
        host_pass = getattr(settings, 'EMAIL_HOST_PASSWORD', '')
        from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', 'NOT SET')

        self.stdout.write(f'  EMAIL_BACKEND     : {backend}')
        self.stdout.write(f'  EMAIL_HOST        : {host}')
        self.stdout.write(f'  EMAIL_PORT        : {port}')
        self.stdout.write(f'  EMAIL_USE_TLS     : {use_tls}')
        self.stdout.write(f'  EMAIL_HOST_USER   : {host_user or "(empty)"}')
        self.stdout.write(f'  EMAIL_HOST_PASSWORD: {"*" * len(host_pass) if host_pass else "(empty)"}')
        self.stdout.write(f'  DEFAULT_FROM_EMAIL: {from_email}')
        self.stdout.write('')

        # ── Step 2: Validate configuration ─────────────────────────────
        errors = []

        if 'console' in backend.lower():
            errors.append(
                'EMAIL_BACKEND is set to console — emails print to stdout, not delivered.\n'
                '  Fix: Set EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend in .env'
            )

        if not host_user:
            errors.append(
                'EMAIL_HOST_USER is empty — no sender email configured.\n'
                '  Fix: Set EMAIL_HOST_USER=your-email@gmail.com in .env'
            )

        if not host_pass:
            errors.append(
                'EMAIL_HOST_PASSWORD is empty — no SMTP password configured.\n'
                '  Fix: Generate a Gmail App Password and set EMAIL_HOST_PASSWORD in .env\n'
                '  Steps: https://myaccount.google.com/apppasswords'
            )

        if 'your-' in host_pass.lower() or 'placeholder' in host_pass.lower():
            errors.append(
                'EMAIL_HOST_PASSWORD appears to be a placeholder — replace with real App Password.\n'
                '  Steps: https://myaccount.google.com/apppasswords'
            )

        if errors:
            self.stdout.write(self.style.ERROR('\n  CONFIGURATION ISSUES FOUND:\n'))
            for i, err in enumerate(errors, 1):
                self.stdout.write(self.style.WARNING(f'  {i}. {err}\n'))

            if options['check_only']:
                raise CommandError('Fix the above issues before sending test emails.')

            if not options['check_only']:
                self.stdout.write(self.style.WARNING(
                    '  Attempting to send anyway (will likely fail)...\n'
                ))
        else:
            self.stdout.write(self.style.SUCCESS('  ✓ Email configuration looks valid!\n'))

        if options['check_only']:
            self.stdout.write(self.style.SUCCESS('  Configuration check complete.\n'))
            return

        # ── Step 3: Send test email ────────────────────────────────────
        recipient = options['to'] or host_user
        if not recipient:
            raise CommandError(
                'No recipient specified. Use --to user@example.com or set EMAIL_HOST_USER.'
            )

        self.stdout.write(f'  Sending test email to: {recipient}')
        self.stdout.write(f'  From: {from_email}')
        self.stdout.write('')

        subject = 'DailyHabits — Email Test ✓'
        now = timezone.now().strftime('%B %d, %Y at %I:%M %p UTC')

        html_content = f"""
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #F8FAFC; padding: 40px 20px;">
  <div style="max-width: 500px; margin: 0 auto; background: #fff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.06);">
    <div style="background: linear-gradient(135deg, #4F46E5, #6366F1); padding: 32px 24px; text-align: center;">
      <div style="font-size: 42px; margin-bottom: 8px;">✅</div>
      <h1 style="color: #fff; font-size: 22px; font-weight: 700; margin: 0;">Email Working!</h1>
    </div>
    <div style="padding: 32px 28px;">
      <p style="color: #1F2933; font-size: 16px;">Hi there,</p>
      <p style="color: #6B7280; font-size: 15px; line-height: 1.6;">
        This confirms that your DailyHabits email system is correctly configured.
        Password reset emails will now be delivered successfully.
      </p>
      <div style="background: #F0FDF4; border-left: 4px solid #22C55E; padding: 14px 16px; border-radius: 0 8px 8px 0; margin: 20px 0;">
        <p style="font-size: 13px; color: #166534; margin: 4px 0;"><strong>Backend:</strong> {backend}</p>
        <p style="font-size: 13px; color: #166534; margin: 4px 0;"><strong>SMTP Host:</strong> {host}:{port}</p>
        <p style="font-size: 13px; color: #166534; margin: 4px 0;"><strong>TLS:</strong> {'Enabled' if use_tls else 'Disabled'}</p>
        <p style="font-size: 13px; color: #166534; margin: 4px 0;"><strong>Sent at:</strong> {now}</p>
      </div>
    </div>
    <div style="background: #F8FAFC; padding: 20px 28px; text-align: center; border-top: 1px solid #E2E8F0;">
      <p style="font-size: 12px; color: #9CA3AF; margin: 0;">&copy; DailyHabits — Your Daily Habit Companion</p>
    </div>
  </div>
</body>
</html>
"""
        text_content = (
            f'DailyHabits Email Test\n\n'
            f'Your email system is correctly configured!\n\n'
            f'Backend: {backend}\n'
            f'SMTP: {host}:{port} (TLS: {use_tls})\n'
            f'Sent at: {now}\n'
        )

        try:
            msg = EmailMultiAlternatives(
                subject=subject,
                body=text_content,
                from_email=from_email,
                to=[recipient],
            )
            msg.attach_alternative(html_content, 'text/html')
            msg.send(fail_silently=False)

            self.stdout.write(self.style.SUCCESS(
                f'  ✓ Test email sent successfully to {recipient}!\n'
                f'  Check your inbox (and spam folder).\n'
            ))
        except Exception as e:
            self.stdout.write(self.style.ERROR(
                f'\n  ✗ Failed to send email!\n'
                f'  Error: {e}\n'
            ))

            # Provide targeted troubleshooting advice
            error_str = str(e).lower()
            if 'authentication' in error_str or 'credentials' in error_str:
                self.stdout.write(self.style.WARNING(
                    '\n  TROUBLESHOOTING: Authentication failed.\n'
                    '  • Ensure you are using a Gmail App Password (NOT your regular password)\n'
                    '  • Generate one at: https://myaccount.google.com/apppasswords\n'
                    '  • 2-Step Verification must be enabled first\n'
                    '  • Copy the 16-character password (without spaces) to EMAIL_HOST_PASSWORD in .env\n'
                ))
            elif 'connection' in error_str or 'timeout' in error_str:
                self.stdout.write(self.style.WARNING(
                    '\n  TROUBLESHOOTING: Connection failed.\n'
                    '  • Check your internet connection\n'
                    '  • Verify EMAIL_HOST and EMAIL_PORT are correct\n'
                    '  • Firewall may be blocking port 587\n'
                ))
            elif 'tls' in error_str or 'ssl' in error_str:
                self.stdout.write(self.style.WARNING(
                    '\n  TROUBLESHOOTING: TLS/SSL error.\n'
                    '  • Ensure EMAIL_USE_TLS=True and EMAIL_PORT=587\n'
                    '  • Or use EMAIL_USE_SSL=True with EMAIL_PORT=465\n'
                ))

            raise CommandError('Email delivery failed. See error above.')
