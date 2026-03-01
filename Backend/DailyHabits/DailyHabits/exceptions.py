"""
Custom Exception Handler — DailyHabits API
==========================================

Provides a unified error-response envelope for every API exception so that the
Flutter client can rely on a single, predictable JSON structure::

    {
        "success": false,
        "message": "Human-readable summary",
        "errors":  { "field": ["detail", ...] },
        "status_code": 400
    }

The handler is wired into DRF via the ``EXCEPTION_HANDLER`` setting in
``settings.py`` and transparently wraps both DRF-native exceptions (validation
errors, permission denied, etc.) and unhandled Python exceptions (500).

See Also:
    - DRF exception handling:
      https://www.django-rest-framework.org/api-guide/exceptions/
"""

from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status
import logging

# Module-level logger — messages are emitted under the "DailyHabits.exceptions" namespace.
logger = logging.getLogger(__name__)


def custom_exception_handler(exc, context):
    """
    Unified API exception handler.

    Wraps every error — whether raised by DRF (validation, permission,
    throttle) or an unhandled Python exception — into a consistent
    JSON envelope that the Flutter client can parse uniformly.

    Args:
        exc:     The exception instance.
        context: Dict containing 'view', 'args', 'kwargs', and 'request'.

    Returns:
        Response: A DRF Response with the standardised error body.
    """
    # Delegate to DRF’s default handler first; it returns None for
    # non-DRF exceptions (i.e. unexpected 500 errors).
    response = exception_handler(exc, context)

    if response is not None:
        # DRF recognised the exception — reformat into the unified envelope
        custom_response = {
            'success': False,
            'message': get_error_message(exc, response),
            'errors': get_error_details(response.data),
            'status_code': response.status_code,
        }
        
        # Structured log entry with view context for easier debugging
        logger.error(
            f"API Error: {exc.__class__.__name__} - {custom_response['message']}",
            extra={
                'view': context.get('view').__class__.__name__ if context.get('view') else None,
                'request_data': getattr(context.get('request'), 'data', None),
            }
        )
        
        response.data = custom_response
    else:
        # Unhandled exception — log full traceback and return a safe 500
        logger.exception(f"Unhandled exception: {exc}")
        response = Response(
            {
                'success': False,
                'message': 'An unexpected error occurred',
                'errors': str(exc) if hasattr(exc, '__str__') else 'Unknown error',
                'status_code': status.HTTP_500_INTERNAL_SERVER_ERROR,
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

    return response


def get_error_message(exc, response):
    """
    Extract a human-readable error summary from a DRF exception.

    Priority: exc.detail (string → list[0] → first dict value) then
    a lookup table of HTTP status codes.

    Args:
        exc:      The original exception.
        response: The DRF Response produced by the default handler.

    Returns:
        str: A short, user-facing error message.
    """
    if hasattr(exc, 'detail'):
        if isinstance(exc.detail, str):
            return exc.detail
        elif isinstance(exc.detail, list):
            return exc.detail[0] if exc.detail else 'Validation error'
        elif isinstance(exc.detail, dict):
            # Get first error message
            for key, value in exc.detail.items():
                if isinstance(value, list):
                    return f"{key}: {value[0]}"
                return f"{key}: {value}"
    
    # Fallback: map common HTTP status codes to generic messages
    status_messages = {
        400: 'Bad request',
        401: 'Authentication required',
        403: 'Permission denied',
        404: 'Resource not found',
        405: 'Method not allowed',
        429: 'Too many requests',
        500: 'Internal server error',
    }
    
    return status_messages.get(response.status_code, 'An error occurred')


def get_error_details(data):
    """
    Normalise DRF’s ``response.data`` into a dict for the error envelope.

    DRF may produce a dict, list, or raw string depending on the
    exception type.  This helper guarantees a dict is always returned.

    Args:
        data: The raw ``response.data`` from DRF’s default handler.

    Returns:
        dict: A dictionary suitable for the ``errors`` key.
    """
    if isinstance(data, dict):
        return data
    elif isinstance(data, list):
        return {'errors': data}
    elif isinstance(data, str):
        return {'detail': data}
    return {'detail': str(data)}
