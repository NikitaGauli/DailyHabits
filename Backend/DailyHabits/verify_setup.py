
import os
import django
import inspect

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'DailyHabits.settings')
django.setup()

from django.contrib.auth import get_user_model
User = get_user_model()

print(f"User Model: {User}")
print(f"User Manager: {User.objects}")
print(f"Manager Type: {type(User.objects)}")

# Check create_user signature
import inspect
sig = inspect.signature(User.objects.create_user)
print(f"create_user signature: {sig}")

try:
    print("Attempting to validate arguments...")
    # Does not actually run it, just checks if 'name' is in parameters
    params = sig.parameters
    if 'name' in params:
        print("Success: 'name' is in create_user parameters.")
    else:
        print("FAILURE: 'name' is NOT in create_user parameters.")
        
except Exception as e:
    print(f"Error inspecting signature: {e}")
