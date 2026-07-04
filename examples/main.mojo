from std.builtin.constrained import _field_conforms_to_error

from professor.apple.database import Database

# @fieldwise_init
# struct SomeStruct(Equatable, RegisterPassable):
#     var field: StaticString


def main() raises:
    var db = Database()
    for event in db.events():
        print(event.alias())

    # comptime r = reflect[SomeStruct]
    # comptime names = r.field_names()
    # comptime types = r.field_types()

    # comptime for i in range(names.size):
    #     comptime T = types[i]
    #     comptime assert conforms_to(T, Equatable)
    #     comptime assert _field_conforms_to_error[
    #         Parent=SomeStruct,
    #         FieldIndex=i,
    #         ParentConformsTo="Equatable",
    #     ]()

    #     if r.field_ref[i](self) != r.field_ref[i](other):
    #         return False
    # return True

    # var a = SomeStruct("x")
    # print(a == a)
