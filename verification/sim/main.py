import argparse
import os
from pathlib import Path

from cocotb.runner import get_runner

SCRIPT_DIR = Path(os.path.realpath(__file__)).parent.absolute()


def run_test(simulator: str, test_file: Path, top_module: str, waves: bool, cfile: str):
    hdl_dir = Path(SCRIPT_DIR / "../../rtl")
    sim_dir = Path(SCRIPT_DIR / "../../rtl/sim")
    verilog_files = hdl_dir.rglob("*.v")
    system_verilog_files = hdl_dir.rglob("*.sv")
    #mem_files = hdl_dir.rglob("*.mem")

    verilog_headers = hdl_dir.rglob("*.vh")
    system_verilog_headers = hdl_dir.rglob("*.svh")

    submodule_dir = Path(SCRIPT_DIR / "../../cva6/rtl")
    submodule_verilog_files = submodule_dir.rglob("*.v")
    submodule_system_verilog_files = submodule_dir.rglob("*.sv")
    submodule_verilog_headers = submodule_dir.rglob("*.vh")
    submodule_system_verilog_headers = submodule_dir.rglob("*.svh")

    verilog_sources = (
        list(verilog_files)
        + list(system_verilog_files)
        + list(submodule_verilog_files)
        + list(submodule_system_verilog_files)
        #+ list(mem_files)
    )
    ## sort the sources to make sure that the def and pkg.sv files are at the beginning
    ## otherwise the simulator might not find the packages
    def_sv_paths = [path for path in verilog_sources if str(path).rsplit('/', 1)[-1].startswith("def")]
    pkg_sv_paths = [path for path in verilog_sources if str(path).endswith("pkg.sv")]
    other_paths = [path for path in verilog_sources if not str(path).rsplit('/', 1)[-1].startswith("def") and not str(path).endswith("pkg.sv")]
    verilog_sources = list(def_sv_paths) + list(pkg_sv_paths) + list(other_paths)

    include_dirs = [
        header.parent
        for header in list(verilog_headers)
        + list(system_verilog_headers)
        + list(submodule_verilog_headers)
        + list(submodule_system_verilog_headers)
    ]

    # subdirectories = [x[0] for x in os.walk(hdl_dir)]
    # include_dirs.extend(subdirectories)

    subdirectories = [x[0] for x in os.walk(submodule_dir)]
    include_dirs.extend(subdirectories)
    include_dirs.extend([sim_dir])
    #include_dirs.extend(mem_files)

    print("\nINCLUDE_DIRS:")
    print(include_dirs)
    print("\nVERILOG_SOURCES:")
    print(verilog_sources)

    runner = get_runner(simulator)
    runner.build(
        verilog_sources=verilog_sources,
        includes=include_dirs,
        hdl_toplevel=top_module,
        always=True,
    )

    runner.test(
        hdl_toplevel=top_module,
        test_module=str(test_file),
        waves=waves,
        plusargs=["+nowarnTSCALE"],
        extra_env={
            "COCOTB_HDL_TIMEUNIT": "1ns",
            "COCOTB_HDL_TIMEPRECISION": "1ps",
            "CFILE": cfile,
        },
        pre_cmd=[
            'set WildcardFilter {};set WildcardSizeThreshold "16777216"; coverage save -onexit covres.ucdb;'
        ],
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--sim", type=str, help="Simulator. <icarus, verilator, questa>"
    )
    parser.add_argument(
        "--top", type=str, help="Top level hdl module to test a.k.a DUT"
    )
    parser.add_argument(
        "--test",
        type=str,
        help="Python test file to run, all tests inside will be run",
    )
    parser.add_argument("--waves", type=bool, help="Dump waves? <true,false>")

    parser.add_argument("--cfile", type=str, help="Test file to run")

    args = parser.parse_args()

    test_dir = Path(SCRIPT_DIR / "tb")
    tests = list(test_dir.rglob("*.py"))
    print("test_dir: ", test_dir)
    print("tests: ", tests)

    test_names = {test.stem: test for test in test_dir.rglob("*.py")}

    # if args.test not in test_names:
    #     raise FileNotFoundError(f"Can't find <{args.test}> in <{tests}>")

    run_test(args.sim, args.test, args.top, args.waves, args.cfile)
