from rest_framework import viewsets, permissions
from .models import Trip, List, ListItem
from .serializers import TripSerializer, ListSerializer, ListItemSerializer


class TripViewSet(viewsets.ModelViewSet):
    serializer_class = TripSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Trip.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class ListViewSet(viewsets.ModelViewSet):
    serializer_class = ListSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = List.objects.filter(trip__user=self.request.user)

        trip_id = self.request.query_params.get('trip')
        if trip_id:
            queryset = queryset.filter(trip_id=trip_id)

        return queryset.order_by('position', 'created_at')

    def perform_create(self, serializer):
        serializer.save()

class ListItemViewSet(viewsets.ModelViewSet):
    serializer_class = ListItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = ListItem.objects.filter(list__trip__user=self.request.user)

        list_id = self.request.query_params.get('list')
        if list_id:
            queryset = queryset.filter(list_id=list_id)

        return queryset.order_by('position', 'created_at')

    def perform_create(self, serializer):
        serializer.save()