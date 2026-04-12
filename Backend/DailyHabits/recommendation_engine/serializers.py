from rest_framework import serializers

from .models import HabitClusterPrediction


class HabitSampleSerializer(serializers.Serializer):
    frequency = serializers.CharField(max_length=30)
    completion_rate = serializers.FloatField(min_value=0.0, max_value=100.0)
    streak = serializers.IntegerField(min_value=0)
    category = serializers.CharField(max_length=100)


class PredictHabitRequestSerializer(serializers.Serializer):
    habits = HabitSampleSerializer(many=True, required=False)

    # Optional single-sample shorthand payload
    frequency = serializers.CharField(max_length=30, required=False)
    completion_rate = serializers.FloatField(min_value=0.0, max_value=100.0, required=False)
    streak = serializers.IntegerField(min_value=0, required=False)
    category = serializers.CharField(max_length=100, required=False)

    def validate(self, attrs):
        has_list = bool(attrs.get('habits'))
        has_single = all(
            key in attrs
            for key in ('frequency', 'completion_rate', 'streak', 'category')
        )

        if not has_list and not has_single:
            raise serializers.ValidationError(
                'Provide either habits[] or single fields: frequency, completion_rate, streak, category.'
            )
        return attrs


class HabitClusterPredictionSerializer(serializers.ModelSerializer):
    class Meta:
        model = HabitClusterPrediction
        fields = [
            'id',
            'cluster_id',
            'cluster_label',
            'insight_message',
            'recommendations',
            'source',
            'cluster_breakdown',
            'created_at',
        ]
