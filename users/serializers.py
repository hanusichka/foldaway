from django.contrib.auth.models import User
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from django.contrib.auth.tokens import default_token_generator
from django.utils.encoding import force_str
from django.utils.http import urlsafe_base64_decode


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    email = serializers.EmailField(required=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password']

    def validate_email(self, value):
        email = value.strip().lower()

        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError('Користувач із таким email вже існує.')

        return email

    def validate_username(self, value):
        username = value.strip()

        if User.objects.filter(username__iexact=username).exists():
            raise serializers.ValidationError('Користувач із таким іменем вже існує.')

        return username

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
        )

        user.is_active = False
        user.save(update_fields=['is_active'])

        return user


class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = User.USERNAME_FIELD

    def validate(self, attrs):
        login_value = attrs.get('username')
        password = attrs.get('password')

        if not login_value or not password:
            raise serializers.ValidationError(
                'Введіть імʼя користувача або email і пароль.'
            )

        login_value = login_value.strip()

        user = User.objects.filter(username__iexact=login_value).first()

        if user is None:
            user = User.objects.filter(email__iexact=login_value).first()

        if user is None:
            raise serializers.ValidationError(
                'Користувача з такими даними не знайдено.'
            )

        if not user.check_password(password):
            raise serializers.ValidationError(
                'Невірний пароль.'
            )

        if not user.is_active:
            raise serializers.ValidationError(
                'Email ще не підтверджено. Перевірте пошту та перейдіть за посиланням.'
            )

        refresh = self.get_token(user)

        return {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
            },
        }
    
class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)

    def validate_email(self, value):
        return value.strip().lower()


class PasswordResetConfirmSerializer(serializers.Serializer):
    uid = serializers.CharField(required=True)
    token = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, min_length=6, write_only=True)

    def validate(self, attrs):
        try:
            uid = force_str(urlsafe_base64_decode(attrs['uid']))
            user = User.objects.get(pk=uid)
        except Exception:
            raise serializers.ValidationError('Некоректне посилання для скидання пароля.')

        if not default_token_generator.check_token(user, attrs['token']):
            raise serializers.ValidationError('Посилання недійсне або застаріле.')

        attrs['user'] = user
        return attrs

    def save(self):
        user = self.validated_data['user']
        user.set_password(self.validated_data['new_password'])
        user.save(update_fields=['password'])
        return user