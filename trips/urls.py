from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import TripViewSet, ListViewSet, ListItemViewSet

router = DefaultRouter()
router.register(r'trips', TripViewSet, basename='trip')
router.register(r'lists', ListViewSet, basename='list')
router.register(r'items', ListItemViewSet, basename='item')

urlpatterns = [
    path('', include(router.urls)),
]