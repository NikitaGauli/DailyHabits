from __future__ import annotations

from datetime import timedelta
import logging
from collections import Counter
from statistics import mode
from typing import Any

import numpy as np
from django.conf import settings
from django.utils import timezone

from habits.models import Habit, HabitLog

from .model_loader import get_kmeans_model
from .models import HabitClusterPrediction
from .preprocess import preprocess_sample

logger = logging.getLogger(__name__)


DEFAULT_CLUSTER_PROFILES = {
    0: {
        'label': 'Highly Consistent Builder',
        'insight': 'You maintain strong completion patterns and stable streaks.',
        'recommendations': [
            'Keep challenge level progressive to avoid plateaus.',
            'Pair top habits with weekly reflection for long-term growth.',
        ],
    },
    1: {
        'label': 'Momentum Seeker',
        'insight': 'You show positive momentum but consistency drops on difficult days.',
        'recommendations': [
            'Use short fallback versions for low-energy days.',
            'Schedule reminders at your highest-completion hour.',
        ],
    },
    2: {
        'label': 'Needs Stabilization',
        'insight': 'Your current routine is irregular and benefits from simpler structure.',
        'recommendations': [
            'Start with smaller goals and increase slowly.',
            'Track one priority habit before expanding your routine.',
            'Enable stronger reminder cadence for critical habits.',
        ],
    },
}


class RecommendationEngineService:
    @staticmethod
    def _align_feature_vector(vector: list[float], expected_size: int) -> list[float]:
        """Align a preprocessed vector to the model's expected feature count.

        This keeps inference resilient when a deployed model was trained with
        a different feature width than the current app configuration.
        """
        current_size = len(vector)
        if current_size == expected_size:
            return vector

        if current_size < expected_size:
            return [*vector, *([0.0] * (expected_size - current_size))]

        return vector[:expected_size]

    @staticmethod
    def _get_cluster_profile(cluster_id: int) -> dict[str, Any]:
        configured = getattr(settings, 'ML_KMEANS_CLUSTER_PROFILES', None)
        profiles = configured or DEFAULT_CLUSTER_PROFILES

        profile = profiles.get(cluster_id)
        if profile:
            return profile

        return {
            'label': f'Cluster {cluster_id}',
            'insight': 'Pattern detected. Keep tracking to unlock more accurate guidance.',
            'recommendations': ['Continue tracking for 7 more days to refine recommendations.'],
        }

    @staticmethod
    def _derive_completion_rate_for_habit(habit: Habit) -> float:
        end_date = timezone.localdate()
        start_date = end_date - timedelta(days=30)

        logs = HabitLog.objects.filter(habit=habit, date__gte=start_date, date__lte=end_date)
        total_logs = logs.count()
        if total_logs == 0:
            return 0.0

        completed_count = logs.filter(status='completed').count()
        return round((completed_count / total_logs) * 100.0, 2)

    @classmethod
    def build_samples_from_user_data(cls, user) -> list[dict[str, Any]]:
        habits = Habit.objects.filter(user=user, is_deleted=False, status='active').prefetch_related('logs')
        samples: list[dict[str, Any]] = []

        for habit in habits:
            samples.append(
                {
                    'frequency': habit.frequency,
                    'completion_rate': cls._derive_completion_rate_for_habit(habit),
                    'streak': habit.current_streak,
                    'category': habit.category_name or 'General',
                }
            )

        return samples

    @classmethod
    def predict_and_store(
        cls,
        *,
        user,
        samples: list[dict[str, Any]],
        source: str = 'on_demand',
    ) -> dict[str, Any]:
        if not samples:
            raise ValueError('No habit samples available for prediction.')

        model = get_kmeans_model()
        processed = [preprocess_sample(sample) for sample in samples]

        expected_features = getattr(model, 'n_features_in_', None)
        if isinstance(expected_features, (int, np.integer)) and expected_features > 0:
            if processed and len(processed[0]) != int(expected_features):
                logger.warning(
                    'Feature width mismatch detected. model_expected=%s app_generated=%s. '
                    'Auto-aligning vectors for compatibility.',
                    int(expected_features),
                    len(processed[0]),
                )
            processed = [
                cls._align_feature_vector(sample, int(expected_features))
                for sample in processed
            ]

        feature_array = np.array(processed, dtype=float)

        predictions = model.predict(feature_array)
        prediction_list = [int(cluster_id) for cluster_id in predictions.tolist()]

        try:
            dominant_cluster = mode(prediction_list)
        except Exception:
            dominant_cluster = Counter(prediction_list).most_common(1)[0][0]

        profile = cls._get_cluster_profile(dominant_cluster)

        breakdown: dict[str, int] = {}
        for cluster_id, count in Counter(prediction_list).items():
            breakdown[str(cluster_id)] = count

        record = HabitClusterPrediction.objects.create(
            user=user,
            cluster_id=dominant_cluster,
            cluster_label=profile['label'],
            insight_message=profile['insight'],
            recommendations=profile['recommendations'],
            source=source,
            input_payload={'samples': samples},
            processed_features=processed,
            cluster_breakdown=breakdown,
        )

        logger.info(
            'Habit prediction generated for user=%s cluster=%s source=%s',
            user.id,
            dominant_cluster,
            source,
        )

        return {
            'prediction_id': int(getattr(record, 'pk', 0)),
            'cluster_group': dominant_cluster,
            'cluster_label': profile['label'],
            'insight': profile['insight'],
            'recommendations': profile['recommendations'],
            'cluster_breakdown': breakdown,
            'sample_count': len(samples),
            'created_at': record.created_at,
        }
