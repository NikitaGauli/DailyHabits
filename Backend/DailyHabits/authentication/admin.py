from django.contrib import admin
from .models import User, LoginActivity, DataDeletionRequest


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ('email', 'name', 'is_active', 'created_at')
    search_fields = ('email', 'name')


@admin.register(LoginActivity)
class LoginActivityAdmin(admin.ModelAdmin):
    list_display = ('user', 'ip_address', 'device_type', 'was_successful', 'login_at')
    list_filter = ('was_successful', 'device_type')
    readonly_fields = ('user', 'ip_address', 'user_agent', 'device_type', 'login_at', 'was_successful')


@admin.register(DataDeletionRequest)
class DataDeletionRequestAdmin(admin.ModelAdmin):
    list_display = ('user', 'status', 'requested_at', 'processed_at')
    list_filter = ('status',)
