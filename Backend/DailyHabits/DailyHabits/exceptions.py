"""
Custom Exception Handler for DailyHabits API
Provides consistent error response format
"""

from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status
import logging

logger = logging.getLogger(__name__)


def custom_exception_handler(exc, context):
    """
    Custom exception handler that provides a consistent error response format.
    """
    # Call REST framework's default exception handler first
    response = exception_handler(exc, context)

    if response is not None:
        # Customize the response format
        custom_response = {
            'success': False,
            'message': get_error_message(exc, response),
            'errors': get_error_details(response.data),
            'status_code': response.status_code,
        }
        
        # Log the error
        logger.error(
            f"API Error: {exc.__class__.__name__} - {custom_response['message']}",
            extra={
                'view': context.get('view').__class__.__name__ if context.get('view') else None,
                'request_data': getattr(context.get('request'), 'data', None),
            }
        )
        
        response.data = custom_response
    else:
        # Handle unexpected exceptions
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
    """Extract a human-readable error message from the exception."""
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
    
    # Default messages based on status code
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
    """Format error details for response."""
    if isinstance(data, dict):
        return data
    elif isinstance(data, list):
        return {'errors': data}
    elif isinstance(data, str):
        return {'detail': data}
    return {'detail': str(data)}
