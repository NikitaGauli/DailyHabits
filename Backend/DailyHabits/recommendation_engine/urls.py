from django.urls import path

from .views import (
    PredictHabitsAPIView,
    PredictHabitsAutoAPIView,
    PredictHabitsHistoryAPIView,
    UploadKMeansModelAPIView,
)

urlpatterns = [
    path('predict-habits/', PredictHabitsAPIView.as_view(), name='predict-habits'),
    path('predict-habits/auto/', PredictHabitsAutoAPIView.as_view(), name='predict-habits-auto'),
    path('predict-habits/history/', PredictHabitsHistoryAPIView.as_view(), name='predict-habits-history'),
    path('predict-habits/model/upload/', UploadKMeansModelAPIView.as_view(), name='predict-habits-model-upload'),
]
