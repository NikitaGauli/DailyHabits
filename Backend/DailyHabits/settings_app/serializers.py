"""
Settings App - Serializers
==========================
DRF serializers for all settings-app models.
"""

from rest_framework import serializers
from .models import (
    UserSettings, PrivacySettings, SecuritySettings,
    LoginSession, SettingsAuditLog, ExportRequest,
    PrivacyPolicy, FAQ, SupportTicket,
)


class UserSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserSettings
        exclude = ['id', 'user', 'created_at', 'updated_at']


class PrivacySettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrivacySettings
        exclude = ['id', 'user', 'created_at', 'updated_at']


class SecuritySettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = SecuritySettings
        exclude = ['id', 'user', 'created_at', 'updated_at']


class LoginSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = LoginSession
        fields = [
            'id', 'session_key', 'device_name', 'device_type', 'platform',
            'ip_address', 'location', 'is_current', 'is_active',
            'last_active_at', 'logged_in_at', 'logged_out_at',
        ]
        read_only_fields = [
            'id', 'session_key', 'device_name', 'device_type', 'platform',
            'ip_address', 'location', 'is_current', 'is_active',
            'last_active_at', 'logged_in_at', 'logged_out_at',
        ]


class SettingsAuditLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = SettingsAuditLog
        fields = [
            'id', 'category', 'action', 'description',
            'old_value', 'new_value', 'ip_address', 'created_at',
        ]
        read_only_fields = fields


class ExportRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExportRequest
        fields = [
            'id', 'export_format', 'date_from', 'date_to',
            'status', 'file_url', 'error_message',
            'created_at', 'completed_at',
        ]
        read_only_fields = ['id', 'status', 'file_url', 'error_message', 'created_at', 'completed_at']


class PrivacyPolicySerializer(serializers.ModelSerializer):
    class Meta:
        model = PrivacyPolicy
        fields = ['id', 'version', 'title', 'content', 'effective_date', 'is_current', 'created_at']


class FAQSerializer(serializers.ModelSerializer):
    class Meta:
        model = FAQ
        fields = ['id', 'question', 'answer', 'category', 'sort_order']


class SupportTicketSerializer(serializers.ModelSerializer):
    class Meta:
        model = SupportTicket
        fields = [
            'id', 'subject', 'description', 'category', 'priority',
            'status', 'screenshot_url', 'admin_response',
            'resolved_at', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'status', 'admin_response', 'resolved_at', 'created_at', 'updated_at']
