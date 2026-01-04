from rest_framework import serializers
from .models import Habit

class HabitSerializer(serializers.ModelSerializer):
    iconCode = serializers.IntegerField(source='icon_code')
    colorValue = serializers.IntegerField(source='color_value')
    isCompleted = serializers.BooleanField(source='is_completed')

    class Meta:
        model = Habit
        fields = ['id', 'title', 'time', 'category', 'iconCode', 'colorValue', 'isCompleted']
        read_only_fields = ['id']

    def create(self, validated_data):
        # Assign current user to the habit
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)
