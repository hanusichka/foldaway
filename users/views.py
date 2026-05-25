from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.shortcuts import get_object_or_404
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from .serializers import (
    EmailTokenObtainPairSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    RegisterSerializer,
)

def send_verification_email(request, user):
    uid = urlsafe_base64_encode(force_bytes(user.pk))
    token = default_token_generator.make_token(user)

    base_url = getattr(settings, 'BACKEND_BASE_URL', None)

    if not base_url:
        base_url = request.build_absolute_uri('/').rstrip('/')

    verification_url = f'{base_url}/api/auth/verify-email/{uid}/{token}/'

    subject = 'Підтвердження email для Foldaway'

    message = (
        f'Привіт, {user.username}!\n\n'
        'Дякуємо за реєстрацію у Foldaway.\n'
        'Щоб активувати акаунт, перейдіть за посиланням:\n\n'
        f'{verification_url}\n\n'
        'Якщо ви не створювали акаунт у Foldaway, просто проігноруйте цей лист.'
    )

    send_mail(
        subject=subject,
        message=message,
        from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', None),
        recipient_list=[user.email],
        fail_silently=False,
    )

def send_password_reset_email(request, user):
    uid = urlsafe_base64_encode(force_bytes(user.pk))
    token = default_token_generator.make_token(user)

    frontend_url = getattr(settings, 'FRONTEND_BASE_URL', 'http://localhost:8080')

    reset_url = f'{frontend_url}/#/reset-password?uid={uid}&token={token}'
    subject = 'Відновлення пароля для Foldaway'

    message = (
        f'Привіт, {user.username}!\n\n'
        'Ми отримали запит на відновлення пароля для вашого акаунта Foldaway.\n'
        'Щоб створити новий пароль, перейдіть за посиланням:\n\n'
        f'{reset_url}\n\n'
        'Якщо ви не надсилали цей запит, просто проігноруйте цей лист.'
    )

    send_mail(
        subject=subject,
        message=message,
        from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', None),
        recipient_list=[user.email],
        fail_silently=False,
    )



class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = [permissions.AllowAny]
    serializer_class = RegisterSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = serializer.save()
        send_verification_email(request, user)

        return Response(
            {
                'message': (
                    'Реєстрація успішна. Ми надіслали лист для підтвердження email.'
                )
            },
            status=status.HTTP_201_CREATED,
        )


class VerifyEmailView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, uidb64, token):
        try:
            uid = force_str(urlsafe_base64_decode(uidb64))
            user = get_object_or_404(User, pk=uid)
        except Exception:
            return Response(
                {'error': 'Некоректне посилання для підтвердження.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if user.is_active:
            return Response(
                {'message': 'Email вже підтверджено. Можете увійти в акаунт.'},
                status=status.HTTP_200_OK,
            )

        if default_token_generator.check_token(user, token):
            user.is_active = True
            user.save(update_fields=['is_active'])

            return Response(
                {'message': 'Email успішно підтверджено. Тепер можете увійти в акаунт.'},
                status=status.HTTP_200_OK,
            )

        return Response(
            {'error': 'Посилання недійсне або застаріле.'},
            status=status.HTTP_400_BAD_REQUEST,
        )


class ResendVerificationEmailView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()

        if not email:
            return Response(
                {'error': 'Вкажіть email.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(email__iexact=email).first()

        success_message = {
            'message': 'Якщо такий акаунт існує і ще не підтверджений, ми надіслали лист повторно.'
        }

        if not user or user.is_active:
            return Response(success_message, status=status.HTTP_200_OK)

        send_verification_email(request, user)
        return Response(success_message, status=status.HTTP_200_OK)


class EmailTokenObtainPairView(TokenObtainPairView):
    permission_classes = [permissions.AllowAny]
    serializer_class = EmailTokenObtainPairSerializer


class LogoutView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data['refresh']
            token = RefreshToken(refresh_token)
            token.blacklist()
            return Response({'message': 'Logged out successfully'})
        except Exception:
            return Response({'error': 'Invalid token'}, status=400)
        

class PasswordResetRequestView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data['email']

        user = User.objects.filter(email__iexact=email).first()

        success_message = {
            'message': 'Якщо акаунт із таким email існує, ми надіслали лист для відновлення пароля.'
        }

        if not user:
            return Response(success_message, status=status.HTTP_200_OK)

        send_password_reset_email(request, user)

        return Response(success_message, status=status.HTTP_200_OK)


class PasswordResetConfirmView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(
            {'message': 'Пароль успішно змінено. Тепер можете увійти.'},
            status=status.HTTP_200_OK,
        )