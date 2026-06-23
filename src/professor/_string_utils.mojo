from professor._ffi_types import ConstCStringPointer
from std.ffi import CStringSlice


def _cstr_to_slice[
    origin: ImmutOrigin
](ptr: ConstCStringPointer) -> StringSlice[origin]:
    """Reclaims a tracked origin for a C string borrowed from the FFI layer.

    Safety:
        The caller must ensure the memory behind `ptr` stays valid for at
        least `origin` (e.g. it is owned by the `Database` that `origin`
        is tied to) and that it is null-terminated UTF-8.
    """
    var cstr = CStringSlice[origin](
        unsafe_from_ptr=ptr.value().unsafe_origin_cast[origin]()
    )
    return StringSlice[origin](unsafe_from_utf8=cstr)


def _cstr_to_slice_opt[
    origin: ImmutOrigin
](ptr: ConstCStringPointer) -> Optional[StringSlice[origin]]:
    if not ptr:
        return None
    return _cstr_to_slice[origin](ptr)
