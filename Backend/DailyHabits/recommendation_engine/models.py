from django.conf import settings
from django.db import models


class HabitClusterPrediction(models.Model):
    SOURCE_CHOICES = [
        ('on_demand', 'On Demand'),
        ('weekly', 'Weekly Scheduled'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='habit_cluster_predictions',
    )
    cluster_id = models.IntegerField()
    cluster_label = models.CharField(max_length=120)
    insight_message = models.TextField()
    recommendations = models.JSONField(default=list)
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default='on_demand')

    input_payload = models.JSONField(default=dict)
    processed_features = models.JSONField(default=list)
    cluster_breakdown = models.JSONField(default=dict)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'habit_cluster_predictions'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'created_at']),
            models.Index(fields=['user', 'cluster_id']),
        ]

    def __str__(self) -> str:
        return f'{self.user.email} -> cluster {self.cluster_id} ({self.cluster_label})'
