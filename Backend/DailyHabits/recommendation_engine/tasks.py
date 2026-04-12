import logging

from celery import shared_task
from django.contrib.auth import get_user_model

from .services import RecommendationEngineService

logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=1, default_retry_delay=60)
def run_weekly_habit_analysis(self):
    """Generate weekly ML habit analysis for active users."""

    user_model = get_user_model()
    users = user_model.objects.filter(is_active=True)

    processed = 0
    for user in users.iterator():
        try:
            samples = RecommendationEngineService.build_samples_from_user_data(user)
            if not samples:
                continue

            RecommendationEngineService.predict_and_store(
                user=user,
                samples=samples,
                source='weekly',
            )
            processed += 1
        except Exception:  # pragma: no cover
            logger.exception('Weekly habit analysis failed for user=%s', user.id)

    logger.info('Weekly habit analysis completed. processed_users=%s', processed)
    return processed
