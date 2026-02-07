from django.contrib import admin
from .models import ShareCard, SharingPrivacy, ReferralLink, Referral, GroupHabit, GroupMember


@admin.register(ShareCard)
class ShareCardAdmin(admin.ModelAdmin):
    list_display = ('user', 'share_type', 'title', 'completion_rate', 'created_at')
    list_filter = ('share_type', 'status')
    search_fields = ('user__email', 'title')


@admin.register(SharingPrivacy)
class SharingPrivacyAdmin(admin.ModelAdmin):
    list_display = ('user', 'habit', 'allow_in_summary', 'allow_streak_share')
    list_filter = ('allow_in_summary', 'allow_streak_share')


@admin.register(ReferralLink)
class ReferralLinkAdmin(admin.ModelAdmin):
    list_display = ('referrer', 'code', 'uses_count', 'max_uses', 'is_active')
    list_filter = ('is_active',)


@admin.register(Referral)
class ReferralAdmin(admin.ModelAdmin):
    list_display = ('referrer', 'referred_user', 'created_at')


@admin.register(GroupHabit)
class GroupHabitAdmin(admin.ModelAdmin):
    list_display = ('name', 'creator', 'invite_code', 'member_count', 'is_active')
    list_filter = ('is_active',)


@admin.register(GroupMember)
class GroupMemberAdmin(admin.ModelAdmin):
    list_display = ('user', 'group', 'role', 'joined_at', 'is_active')
    list_filter = ('role', 'is_active')
