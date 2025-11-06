"""Health check views for ECS/ALB monitoring"""
from django.db import connection
from django.http import JsonResponse
from django.views.decorators.http import require_GET
from django.core.cache import cache


@require_GET
def liveness(request):
    """
    Liveness probe - indicates if the application is running.
    Used by ECS container health checks.
    """
    return JsonResponse({'status': 'ok', 'service': 'django-api'}, status=200)


@require_GET
def readiness(request):
    """
    Readiness probe - indicates if the application is ready to serve traffic.
    Checks database and cache connectivity.
    Used by ALB target group health checks.
    """
    checks = {
        'database': False,
        'cache': False,
    }

    # Check database connection
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
        checks['database'] = True
    except Exception as e:
        pass

    # Check cache connection (if Redis is configured)
    try:
        cache.set('health_check', 'ok', 10)
        checks['cache'] = cache.get('health_check') == 'ok'
    except Exception as e:
        checks['cache'] = True  # Cache is optional, don't fail if not available

    # Service is ready if database is accessible
    all_healthy = checks['database']
    status_code = 200 if all_healthy else 503

    return JsonResponse({
        'status': 'healthy' if all_healthy else 'unhealthy',
        'checks': checks
    }, status=status_code)
