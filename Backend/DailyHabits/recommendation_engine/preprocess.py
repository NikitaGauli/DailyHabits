from __future__ import annotations

from typing import Any

from django.conf import settings


def _normalize_completion_rate(value: float) -> float:
    # Allow both 0..1 and 0..100 client formats.
    if value <= 1.0:
        return value * 100.0
    return value


def _encode_from_map(value: str, mapping: dict[str, int], fallback: int = -1) -> int:
    return mapping.get(value.lower().strip(), fallback)


def get_feature_order() -> list[str]:
    return getattr(
        settings,
        'ML_KMEANS_FEATURE_ORDER',
        ['frequency', 'completion_rate', 'streak', 'category'],
    )


def preprocess_sample(sample: dict[str, Any]) -> list[float]:
    """
    Convert a single habit sample to the exact numeric feature order used in training.

    Keep ML_KMEANS_FEATURE_ORDER / encoders in settings synchronized with your training notebook.
    """
    frequency_map = getattr(
        settings,
        'ML_KMEANS_FREQUENCY_MAP',
        {'daily': 0, 'weekly': 1, 'custom': 2},
    )
    category_map = getattr(
        settings,
        'ML_KMEANS_CATEGORY_MAP',
        {
            'health': 0,
            'fitness': 1,
            'study': 2,
            'mindfulness': 3,
            'productivity': 4,
            'creativity': 5,
            'social': 6,
            'general': 7,
            'custom': 8,
        },
    )

    completion_rate = _normalize_completion_rate(float(sample['completion_rate']))

    encoded = {
        'frequency': float(_encode_from_map(str(sample['frequency']), frequency_map)),
        'completion_rate': float(completion_rate),
        'streak': float(sample['streak']),
        'category': float(_encode_from_map(str(sample['category']), category_map)),
    }

    return [encoded[name] for name in get_feature_order()]
