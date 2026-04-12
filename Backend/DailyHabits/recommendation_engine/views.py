import logging
from pathlib import Path
from typing import Any, cast

from django.conf import settings
from rest_framework import status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .model_loader import get_kmeans_model
from .models import HabitClusterPrediction
from .serializers import (
    HabitClusterPredictionSerializer,
    PredictHabitRequestSerializer,
)
from .services import RecommendationEngineService

logger = logging.getLogger(__name__)


class PredictHabitsAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = PredictHabitRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {
                    'success': False,
                    'message': 'Invalid input payload.',
                    'errors': serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        data = cast(dict[str, Any], serializer.validated_data)
        samples = cast(list[dict[str, Any]] | None, data.get('habits'))

        if not samples:
            samples = [
                {
                    'frequency': data['frequency'],
                    'completion_rate': data['completion_rate'],
                    'streak': data['streak'],
                    'category': data['category'],
                }
            ]

        try:
            result = RecommendationEngineService.predict_and_store(
                user=request.user,
                samples=samples,
                source='on_demand',
            )
        except ValueError as exc:
            return Response(
                {'success': False, 'message': str(exc)},
                status=status.HTTP_400_BAD_REQUEST,
            )
        except Exception as exc:  # pragma: no cover
            logger.exception('Habit prediction failed for user=%s', request.user.id)
            return Response(
                {
                    'success': False,
                    'message': 'Unable to run habit prediction right now.',
                    'detail': str(exc),
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response({'success': True, 'data': result}, status=status.HTTP_200_OK)


class PredictHabitsHistoryAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        limit = min(int(request.query_params.get('limit', 20)), 100)
        queryset = HabitClusterPrediction.objects.filter(user=request.user)[:limit]
        serializer = HabitClusterPredictionSerializer(queryset, many=True)

        return Response(
            {
                'success': True,
                'count': len(serializer.data),
                'results': serializer.data,
            },
            status=status.HTTP_200_OK,
        )


class PredictHabitsAutoAPIView(APIView):
    """On-demand endpoint that derives habit samples from user records."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            samples = RecommendationEngineService.build_samples_from_user_data(request.user)
            result = RecommendationEngineService.predict_and_store(
                user=request.user,
                samples=samples,
                source='on_demand',
            )
        except ValueError as exc:
            return Response(
                {'success': False, 'message': str(exc)},
                status=status.HTTP_400_BAD_REQUEST,
            )
        except Exception as exc:  # pragma: no cover
            logger.exception('Auto habit prediction failed for user=%s', request.user.id)
            return Response(
                {
                    'success': False,
                    'message': 'Unable to run automatic habit prediction.',
                    'detail': str(exc),
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response({'success': True, 'data': result}, status=status.HTTP_200_OK)


class UploadKMeansModelAPIView(APIView):
    """Upload a new .pkl KMeans model into the configured model directory."""

    permission_classes = [IsAuthenticated, IsAdminUser]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        uploaded_file = request.FILES.get('model_file')
        if uploaded_file is None:
            return Response(
                {
                    'success': False,
                    'message': 'No file uploaded. Use multipart key: model_file.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        filename = uploaded_file.name or ''
        if not filename.lower().endswith('.pkl'):
            return Response(
                {
                    'success': False,
                    'message': 'Invalid file type. Only .pkl files are supported.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if uploaded_file.size > 200 * 1024 * 1024:
            return Response(
                {
                    'success': False,
                    'message': 'File too large. Maximum allowed size is 200 MB.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        models_dir = Path(getattr(settings, 'ML_MODELS_DIR', Path(settings.BASE_DIR) / 'ml_models'))
        models_dir.mkdir(parents=True, exist_ok=True)

        # Keep a stable active filename so deployment/config stays simple.
        destination = models_dir / 'kmeans_model.pkl'
        with destination.open('wb') as output:
            for chunk in uploaded_file.chunks():
                output.write(chunk)

        # Ensure future requests use the newly uploaded model.
        get_kmeans_model.cache_clear()

        return Response(
            {
                'success': True,
                'message': 'Model uploaded successfully.',
                'saved_as': str(destination),
            },
            status=status.HTTP_201_CREATED,
        )
