"""Fetch the soundfonts into the install's HF cache so the first run is instant.

Same trick as the Dockerfile: import the two tiny modules directly, without
importing the muscriptor package (and therefore torch).
"""

import importlib.util
import sys

spec = importlib.util.find_spec("muscriptor")
sys.path.insert(0, spec.submodule_search_locations[0])
sys.path.insert(0, spec.submodule_search_locations[0] + "/utils")

import download  # noqa: E402
import soundfonts  # noqa: E402

download.download_if_necessary(soundfonts.SF2_URL)
download.download_if_necessary(soundfonts.SF3_URL)
