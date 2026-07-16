from std.testing import assert_equal, assert_raises, assert_true, TestSuite

from professor.apple import Architecture, Cpu, Database


def test_cpu_from_database_name_mapping() raises:
    assert_true(Cpu(database_name="a14") == Cpu.M1)
    assert_true(Cpu(database_name="a15") == Cpu.M2)
    assert_true(Cpu(database_name="a16") == Cpu.M3)
    assert_true(Cpu(database_name="as1") == Cpu.M3)
    assert_true(Cpu(database_name="as2") == Cpu.M3)
    assert_true(Cpu(database_name="as3") == Cpu.M3)
    assert_true(Cpu(database_name="as4") == Cpu.M4)
    assert_true(Cpu(database_name="as4-1") == Cpu.M4)
    assert_true(Cpu(database_name="as4-2") == Cpu.M4)
    assert_true(Cpu(database_name="as5") == Cpu.M5)
    assert_true(Cpu(database_name="as5-2") == Cpu.M5)


def test_cpu_from_unknown_database_name_raises() raises:
    with assert_raises(contains="Unrecognised database name"):
        _ = Cpu(database_name="not-a-chip")


def test_cpu_write() raises:
    assert_equal(String(Cpu.M1), "M1")
    assert_equal(String(Cpu.M2), "M2")
    assert_equal(String(Cpu.M3), "M3")
    assert_equal(String(Cpu.M4), "M4")
    assert_equal(String(Cpu.M5), "M5")


def test_cpu_generations_are_distinct() raises:
    var generations = [Cpu.M1, Cpu.M2, Cpu.M3, Cpu.M4, Cpu.M5]
    for i in range(len(generations)):
        for j in range(len(generations)):
            if i != j:
                assert_true(generations[i] != generations[j])


def test_cpu_host_matches_database() raises:
    # `host()` resolves from the compilation target, the database from the
    # loaded kpep files; on a native build they must agree.
    var db = Database()
    assert_true(db.cpu() == Cpu.host())


def test_cpu_id_is_nonempty() raises:
    # kpc_cpu_string works without root privileges.
    var id = Cpu.host().id()
    assert_true(id.byte_length() > 0)


def test_architecture_write() raises:
    assert_equal(String(Architecture.I386), "i386")
    assert_equal(String(Architecture.X86_64), "x86_64")
    assert_equal(String(Architecture.Arm), "arm")
    assert_equal(String(Architecture.Arm64), "arm64")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
