
import uuid
from django.db import models
from django.contrib.auth.models import User


class Trip(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='trips')
    title = models.CharField(max_length=255)
    destination = models.CharField(max_length=255, blank=True)
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    cover_image_url = models.URLField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title


class List(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    trip = models.ForeignKey(Trip, on_delete=models.CASCADE, related_name='lists')
    title = models.CharField(max_length=255)
    icon = models.CharField(max_length=30, default='📍')
    cover_image_url = models.URLField(blank=True, null=True)
    position = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title

    class Meta:
        ordering = ['position']

    def __str__(self):
        return f'{self.trip.title} — {self.title}'


class ListItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    list = models.ForeignKey(List, on_delete=models.CASCADE, related_name='items')
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    address = models.CharField(max_length=500, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    map_symbol = models.CharField(max_length=10, blank=True)
    photo_url = models.TextField(blank=True)
    external_link = models.TextField(blank=True)
    is_done = models.BooleanField(default=False)
    position = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['position']

    def __str__(self):
        return self.title