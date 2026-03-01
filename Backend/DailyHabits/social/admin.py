"""
Social App \u2014 Django Admin Configuration
========================================

Registers all social models with the Django admin site and customises
their list views with relevant columns, filters, and search fields.

Registered models:
    - ``ShareCard`` \u2013 Shareable progress summary cards.
    - ``SharingPrivacy`` \u2013 Per-habit privacy overrides.
    - ``ReferralLink`` \u2013 Invite codes with usage tracking.
    - ``Referral`` \u2013 Successful referral records.
    - ``GroupHabit`` \u2013 Collaborative habit groups.
    - ``GroupMember`` \u2013 Group membership records.
"""


from django.contrib import admin
from django.utils.html import format_html

from .models import (
    ShareCard,
    SharingPrivacy,
    ReferralLink,
    Referral,
    GroupHabit,
    GroupMember,
)


class GroupMemberInline(admin.TabularInline):
    model = GroupMember
    extra = 0
    fields = ['user', 'role', 'is_active', 'joined_at']
    readonly_fields = ['joined_at']


@admin.register(ShareCard)
class ShareCardAdmin(admin.ModelAdmin):
    list_display = ['user', 'share_type', 'title', 'rate_display', 'created_at']
    list_filter = ['share_type', 'status']
    search_fields = ['user__email', 'title']
    list_per_page = 50

    @admin.display(description='Completion Rate')
    def rate_display(self, obj):
        rate = obj.completion_rate or 0
        color = '#16a34a' if rate >= 70 else ('#f59e0b' if rate >= 40 else '#dc2626')
        return format_html('<span style="color:{};font-weight:600;">{:.0f}%</span>', color, rate)


@admin.register(SharingPrivacy)
class SharingPrivacyAdmin(admin.ModelAdmin):
    list_display = ['user', 'habit', 'allow_in_summary', 'allow_streak_share']
    list_filter = ['allow_in_summary', 'allow_streak_share']


@admin.register(ReferralLink)
class ReferralLinkAdmin(admin.ModelAdmin):
    list_display = ['referrer', 'code', 'uses_count', 'max_uses', 'active_badge']
    list_filter = ['is_active']
    search_fields = ['referrer__email', 'code']

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj):
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')


@admin.register(Referral)
class ReferralAdmin(admin.ModelAdmin):
    list_display = ['referrer', 'referred_user', 'created_at']
    search_fields = ['referrer__email', 'referred_user__email']
    date_hierarchy = 'created_at'


@admin.register(GroupHabit)
class GroupHabitAdmin(admin.ModelAdmin):
    list_display = ['name', 'creator', 'invite_code', 'member_count', 'active_badge']
    list_filter = ['is_active']
    search_fields = ['name', 'creator__email']
    inlines = [GroupMemberInline]

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj):
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')


@admin.register(GroupMember)
class GroupMemberAdmin(admin.ModelAdmin):
    list_display = ['user', 'group', 'role_badge', 'joined_at', 'active_badge']
    list_filter = ['role', 'is_active']
    search_fields = ['user__email', 'group__name']

    @admin.display(description='Role', ordering='role')
    def role_badge(self, obj):
        color = '#6366f1' if obj.role == 'admin' else '#94a3b8'
        return format_html('<span style="color:{};font-weight:600;">{}</span>', color, obj.role.capitalize())

    @admin.display(description='Active', ordering='is_active')
    def active_badge(self, obj):
        if obj.is_active:
            return format_html('<span style="color:{};">● Active</span>', '#16a34a')
        return format_html('<span style="color:{};">● Inactive</span>', '#94a3b8')

