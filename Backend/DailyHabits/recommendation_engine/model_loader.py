import logging
import pickle
from functools import lru_cache
from pathlib import Path
from typing import Any

from django.conf import settings

try:
    import joblib
except ImportError:  # pragma: no cover
    joblib = None

logger = logging.getLogger(__name__)


class ModelLoadError(RuntimeError):
    """Raised when a required ML model cannot be loaded."""


def _extract_predictor(model_obj: Any) -> Any:
    """Return the concrete estimator that exposes predict()."""
    if hasattr(model_obj, 'predict'):
        return model_obj

    if isinstance(model_obj, dict):
        # Common keys used when training artifacts are saved as dictionaries.
        for key in ('model', 'kmeans', 'estimator', 'pipeline'):
            candidate = model_obj.get(key)
            if candidate is not None and hasattr(candidate, 'predict'):
                logger.info('Using embedded estimator from pickle dict key: %s', key)
                return candidate

    raise ModelLoadError(
        'Loaded pickle does not contain a valid estimator with a predict() method.'
    )


def _resolve_path(path: Path) -> Path:
    if path.is_absolute():
        return path
    return Path(settings.BASE_DIR) / path


def _discover_in_directory(directory: Path) -> list[Path]:
    if not directory.exists() or not directory.is_dir():
        return []

    preferred = directory / 'kmeans_model.pkl'
    candidates: list[Path] = []
    if preferred.exists():
        candidates.append(preferred)

    # Include any extra pkl files as fallback options.
    for pkl_path in sorted(directory.glob('*.pkl')):
        if pkl_path != preferred:
            candidates.append(pkl_path)
    return candidates


def _candidate_model_paths() -> list[Path]:
    configured = getattr(settings, 'ML_KMEANS_MODEL_PATH', '').strip()
    model_dir = Path(getattr(settings, 'ML_MODELS_DIR', Path(settings.BASE_DIR) / 'ml_models'))

    if configured:
        configured_path = _resolve_path(Path(configured))
        if configured_path.is_dir():
            discovered = _discover_in_directory(configured_path)
            if discovered:
                return discovered
        return [configured_path]

    base_candidates = [
        *_discover_in_directory(model_dir),
        Path(settings.BASE_DIR) / 'kmeans_model.pkl',
        Path(settings.BASE_DIR).parent / 'kmeans_model.pkl',
    ]

    # Keep order while removing duplicates.
    deduped: list[Path] = []
    seen: set[Path] = set()
    for path in base_candidates:
        if path in seen:
            continue
        seen.add(path)
        deduped.append(path)
    return deduped


@lru_cache(maxsize=1)
def get_kmeans_model() -> Any:
    """Load and cache the KMeans model once per process."""
    last_error: Exception | None = None

    for path in _candidate_model_paths():
        if not path.exists():
            continue

        try:
            if joblib is not None:
                model = joblib.load(path)
            else:
                with path.open('rb') as file_obj:
                    model = pickle.load(file_obj)

            model = _extract_predictor(model)

            logger.info('KMeans model loaded successfully from %s', path)
            return model
        except Exception as exc:  # pragma: no cover - runtime environment dependent
            last_error = exc
            logger.exception('Failed to load KMeans model from %s', path)

    if last_error is not None:
        raise ModelLoadError(f'Unable to load KMeans model: {last_error}') from last_error

    raise ModelLoadError(
        'kmeans_model.pkl not found. Set ML_KMEANS_MODEL_PATH, or put the file in Backend/DailyHabits/ml_models/.'
    )
