"""
Authentication Views
apps/authentication/views.py
"""

from django.contrib.auth import authenticate, get_user_model
from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import (
    RegisterSerializer,
    LoginSerializer,
    UserSerializer,
    ChangePasswordSerializer
)
from .models import LoginActivity, DataDeletionRequest

User = get_user_model()


User = get_user_model()


class RegisterView(generics.CreateAPIView):
    """
    API endpoint for user registration
    POST /api/auth/register
    """
    queryset = User.objects.all()
    permission_classes = [AllowAny]
    serializer_class = RegisterSerializer
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        
        if serializer.is_valid():
            user = serializer.save()
            
            # Generate JWT tokens
            refresh = RefreshToken.for_user(user)
            
            return Response({
                'success': True,
                'message': 'User registered successfully',
                'user': UserSerializer(user).data,
                'token': str(refresh.access_token),
                'refresh': str(refresh),
            }, status=status.HTTP_201_CREATED)
        
        return Response({
            'success': False,
            'message': 'Registration failed',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


class LoginView(APIView):
    """
    API endpoint for user login
    POST /api/auth/login
    """
    permission_classes = [AllowAny]
    
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        
        if serializer.is_valid():
            data = serializer.validated_data
            assert data is not None
            email = data.get('email')
            password = data.get('password')
            
            # Authenticate user
            user = authenticate(request, email=email, password=password)
            
            if user is not None:
                # Record successful login
                self._record_login(request, user, success=True)
                
                # Generate JWT tokens
                refresh = RefreshToken.for_user(user)
                
                return Response({
                    'success': True,
                    'message': 'Login successful',
                    'user': UserSerializer(user).data,
                    'token': str(refresh.access_token),
                    'refresh': str(refresh),
                }, status=status.HTTP_200_OK)
            else:
                # Record failed login attempt
                try:
                    failed_user = User.objects.get(email=email)
                    self._record_login(request, failed_user, success=False)
                except User.DoesNotExist:
                    pass
                
                return Response({
                    'success': False,
                    'message': 'Invalid email or password'
                }, status=status.HTTP_401_UNAUTHORIZED)
        
        return Response({
            'success': False,
            'message': 'Invalid data',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
    
    @staticmethod
    def _record_login(request, user, success=True):
        """Record a login activity for auditing."""
        ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', ''))
        if ',' in ip:
            ip = ip.split(',')[0].strip()
        user_agent = request.META.get('HTTP_USER_AGENT', '')
        device = 'mobile' if any(k in user_agent.lower() for k in ['mobile', 'android', 'iphone']) else 'desktop'
        LoginActivity.objects.create(
            user=user,
            ip_address=ip or None,
            user_agent=user_agent[:500],
            device_type=device,
            was_successful=success,
        )


class LogoutView(APIView):
    """
    API endpoint for user logout
    POST /api/auth/logout
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            refresh_token = request.data.get('refresh')
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
            
            return Response({
                'success': True,
                'message': 'Logout successful'
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({
                'success': False,
                'message': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)


class UserProfileView(generics.RetrieveUpdateAPIView):
    """
    API endpoint for getting/updating user profile
    GET/PUT /api/user/profile
    """
    permission_classes = [IsAuthenticated]
    serializer_class = UserSerializer
    
    def get_object(self):
        return self.request.user
    
    def retrieve(self, request, *args, **kwargs):
        user = self.get_object()
        serializer = self.get_serializer(user)
        
        return Response({
            'success': True,
            'user': serializer.data
        }, status=status.HTTP_200_OK)
    
    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        user = self.get_object()
        serializer = self.get_serializer(user, data=request.data, partial=partial)
        
        if serializer.is_valid():
            serializer.save()
            return Response({
                'success': True,
                'message': 'Profile updated successfully',
                'user': serializer.data
            }, status=status.HTTP_200_OK)
        
        return Response({
            'success': False,
            'message': 'Update failed',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


class ChangePasswordView(APIView):
    """
    API endpoint for changing password
    POST /api/auth/change-password
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        
        if serializer.is_valid():
            user = request.user
            data = serializer.validated_data
            assert data is not None
            
            # Check old password
            if not user.check_password(data.get('old_password')):
                return Response({
                    'success': False,
                    'message': 'Old password is incorrect'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Set new password
            user.set_password(data.get('new_password'))
            user.save()
            
            return Response({
                'success': True,
                'message': 'Password changed successfully'
            }, status=status.HTTP_200_OK)
        
        return Response({
            'success': False,
            'message': 'Invalid data',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


class LoginHistoryView(APIView):
    """
    GET /api/auth/login-history/
    Return the user's recent login activity.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        activities = LoginActivity.objects.filter(user=request.user)[:30]
        return Response({
            'success': True,
            'loginHistory': [{
                'id': a.id,
                'ipAddress': a.ip_address,
                'deviceType': a.device_type,
                'userAgent': a.user_agent[:120],
                'location': a.location,
                'loginAt': a.login_at.isoformat(),
                'wasSuccessful': a.was_successful,
            } for a in activities],
        })


class DataExportView(APIView):
    """
    GET /api/auth/data-export/
    Return all personal data in JSON (GDPR data portability).
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from habits.models import Habit, HabitLog
        from django.forms.models import model_to_dict

        user = request.user
        habits = Habit.objects.filter(user=user)
        logs = HabitLog.objects.filter(habit__user=user)

        return Response({
            'success': True,
            'export': {
                'user': {
                    'email': user.email,
                    'name': user.name,
                    'createdAt': user.created_at.isoformat(),
                },
                'habits': [{
                    'title': h.title,
                    'category': h.category,
                    'frequency': h.frequency,
                    'currentStreak': h.current_streak,
                    'bestStreak': h.best_streak,
                    'status': h.status,
                    'createdAt': h.created_at.isoformat(),
                } for h in habits],
                'logs': [{
                    'habitTitle': l.habit.title,
                    'completedAt': l.completed_at.isoformat() if l.completed_at else None,
                    'notes': l.notes,
                } for l in logs[:500]],
            },
        })


class DataDeletionRequestView(APIView):
    """
    POST /api/auth/request-deletion/
    Submit a GDPR-style data-deletion request.
    GET  /api/auth/request-deletion/
    Check the status of an existing request.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        req = DataDeletionRequest.objects.filter(user=request.user).first()
        if not req:
            return Response({'success': True, 'request': None})
        return Response({
            'success': True,
            'request': {
                'id': req.id,
                'status': req.status,
                'reason': req.reason,
                'requestedAt': req.requested_at.isoformat(),
                'processedAt': req.processed_at.isoformat() if req.processed_at else None,
            }
        })

    def post(self, request):
        existing = DataDeletionRequest.objects.filter(
            user=request.user, status__in=['pending', 'processing']
        ).first()
        if existing:
            return Response({
                'success': False,
                'message': 'A deletion request is already in progress.',
            }, status=status.HTTP_409_CONFLICT)
        
        DataDeletionRequest.objects.create(
            user=request.user,
            reason=request.data.get('reason', ''),
        )
        return Response({
            'success': True,
            'message': 'Deletion request submitted. Your data will be processed within 30 days.',
        }, status=status.HTTP_201_CREATED)