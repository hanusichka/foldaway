from rest_framework import serializers
from .models import Trip, List, ListItem
from django.contrib.auth.models import User


class ListItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = ListItem
        fields = '__all__'


class ListSerializer(serializers.ModelSerializer):
    items = ListItemSerializer(many=True, read_only=True)

    class Meta:
        model = List
        fields = '__all__'


class TripMemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email']


class TripSerializer(serializers.ModelSerializer):
    lists = ListSerializer(many=True, read_only=True)
    members = TripMemberSerializer(many=True, read_only=True)
    owner = TripMemberSerializer(source='user', read_only=True)

    class Meta:
        model = Trip
        fields = '__all__'
        read_only_fields = ['user', 'created_at']