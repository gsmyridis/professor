from std.ffi import c_int
from std.testing import assert_equal

from .kperf_data import kpep_config_error_desc


def assert_success(code: c_int) raises:
    """Asserts the code is 0 for success. Otherwise, it prints the error
    description."""
    var error_desc = kpep_config_error_desc(code)
    assert_equal(code, c_int(0), String("error: " + error_desc))
