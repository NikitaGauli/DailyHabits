from django.apps import AppConfig


class AdminPanelConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'admin_panel'
    verbose_name = 'Admin Panel'

    def ready(self):
        from .admin_dashboard import configure_admin_site
        configure_admin_site()
