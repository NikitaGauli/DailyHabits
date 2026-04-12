from django.contrib import admin

from .models import HabitClusterPrediction


@admin.register(HabitClusterPrediction)
class HabitClusterPredictionAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'cluster_id', 'cluster_label', 'source', 'created_at')
    list_filter = ('source', 'cluster_id', 'created_at')
    search_fields = ('user__email', 'cluster_label')
    readonly_fields = ('created_at',)
