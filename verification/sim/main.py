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

    # List of submodule directories to search
    submodule_dirs = [
        Path(SCRIPT_DIR / "../../cva6-softcore-contest/core"),
        Path(SCRIPT_DIR / "../../cva6-softcore-contest/vendor"),
        Path(SCRIPT_DIR / "../../cva6-softcore-contest/common"),
        Path(SCRIPT_DIR / "../../cva6-softcore-contest/corev_apu"),
        Path(SCRIPT_DIR / "../../cva6-softcore-contest/verif/tb/core/tb_components"),
        Path(SCRIPT_DIR / "../../obi"),
        Path(SCRIPT_DIR / "../../safety_island/future/axi_obi")
    ]
    
    # Gather all relevant files from all submodule directories
    submodule_verilog_files = []
    submodule_system_verilog_files = []
    submodule_verilog_headers = []
    submodule_system_verilog_headers = []
    for submodule_dir in submodule_dirs:
        submodule_verilog_files.extend(submodule_dir.rglob("*.v"))
        submodule_system_verilog_files.extend(submodule_dir.rglob("*.sv"))
        submodule_verilog_headers.extend(submodule_dir.rglob("*.vh"))
        submodule_system_verilog_headers.extend(submodule_dir.rglob("*.svh"))
    
    # Combine all verilog sources
    verilog_sources = (
        list(verilog_files)
        + list(system_verilog_files)
        + submodule_verilog_files
        + submodule_system_verilog_files
    )
    
    # Exclude testbenches and specific undesired modules
    verilog_sources = [
        path for path in verilog_sources
        if not str(path).rsplit('/', 1)[-1].startswith("tb_")
        and not str(path).rsplit('/', 1)[-1].startswith("tb.sv")
        and not str(path).rsplit('/', 1)[-1].endswith("_tb.sv")
        and not str(path).rsplit('/', 1)[-1].endswith("_tb.v")
        and "blackbox" not in str(path)
        and "altera" not in str(path)
        and ("fpga" not in str(path) and not str(path).rsplit('/', 1)[-1].endswith("SyncSpRam.sv")
             and not str(path).rsplit('/', 1)[-1].endswith("SyncSpRamBeNx64.sv")
             and not str(path).rsplit('/', 1)[-1].endswith("AsyncDpRam.sv")
             and not str(path).rsplit('/', 1)[-1].endswith("SyncDpRam.sv")
             and not str(path).rsplit('/', 1)[-1].endswith("AsyncThreePortRam.sv"))
        and "openpiton" not in str(path)
        and "tb_cva6" not in str(path)
        and not str(path).rsplit('/', 1)[-1].endswith("spike.sv")
        and not str(path).rsplit('/', 1)[-1].startswith("Sim")
        and not str(path).rsplit('/', 1)[-1].endswith("riscv.sv")
        and "deprecated" not in str(path)
        and "hpdcache" not in str(path)
        and not str(path).rsplit('/', 1)[-1].startswith("hpdcache_wrapper.sv")
        and "hpdcache_to_l15" not in str(path)
        and "wt_l15_adapter" not in str(path)
        and "tb_wb_dcache" not in str(path)
        and "cvxif_example" not in str(path)
        and "mmu_sv39" not in str(path)
        and not str(path).rsplit('/', 1)[-1].endswith("obi_atop_resolver.sv")
        and not str(path).rsplit('/', 1)[-1].endswith("axi_lite_lfsr.sv")
        and not str(path).rsplit('/', 1)[-1].endswith("axi_zero_mem.sv")
        and not str(path).rsplit('/', 1)[-1].endswith("axi_id_serialize.sv")
        and not (str(path).rsplit('/', 1)[-1].endswith("_config_pkg.sv") and not str(path).rsplit('/', 1)[-1].endswith("build_config_pkg.sv")) ## fix config conflict by not including all
    ]
    #and "cache_subsystem/wt_" not in str(path)
    #and not str(path).rsplit('/', 1)[-1].endswith("custom_config.sv")
    #and "hpdcache" not in str(path)

    ## sort the sources to make sure that the def and pkg.sv files are at the beginning
    ## otherwise the simulator might not find the packages
    def_sv_paths = [path for path in verilog_sources if str(path).rsplit('/', 1)[-1].startswith("def")]
    obi_pkg_path = [path for path in verilog_sources if str(path).rsplit('/', 1)[-1].startswith("cf_math_pkg.sv") or str(path).rsplit('/', 1)[-1].startswith("obi_pkg.sv")]
    config_pkg_path = [path for path in verilog_sources if str(path).rsplit('/', 1)[-1].startswith("config_pkg.sv")
                       or str(path).rsplit('/', 1)[-1].startswith("top_pkg.sv")
                       or str(path).rsplit('/', 1)[-1].startswith("ariane_soc_pkg.sv")
                       or str(path).rsplit('/', 1)[-1].startswith("rand_id_queue.sv")]
    cva6_config_pkg_path = [path for path in verilog_sources if str(path).rsplit('/', 1)[-1].startswith("custom_config.sv")]
    riscv_pkg_path = [path for path in verilog_sources if str(path).rsplit('/', 1)[-1].startswith("riscv_pkg.sv")]
    pre_pkg_sv_paths = [path for path in verilog_sources if str(path).endswith("config.sv") or str(path).endswith("config_pkg.sv") or str(path).rsplit('/', 1)[-1].startswith("ariane_pkg.sv") or str(path).endswith("riscv_pkg.sv") or str(path).endswith("axi_pkg.sv") or str(path).endswith("fpnew_pkg.sv")]
    pkg_sv_paths = [path for path in verilog_sources if str(path).endswith("pkg.sv") and not str(path).endswith("config_pkg.sv") and not str(path).endswith("riscv_pkg.sv") and not str(path).endswith("axi_pkg.sv")]
    other_paths = [path for path in verilog_sources if not str(path).rsplit('/', 1)[-1].startswith("def") and not str(path).endswith("pkg.sv")]
    verilog_sources = (
        list(def_sv_paths)
        + list(obi_pkg_path)
        + list(config_pkg_path)
        + list(cva6_config_pkg_path)
        + list(riscv_pkg_path)
        + list(pre_pkg_sv_paths)
        + list([Path(SCRIPT_DIR / "../../cva6-softcore-contest/corev_apu/tb/ariane_axi_pkg.sv")])
        + list([Path(SCRIPT_DIR / "../../cva6-softcore-contest/vendor/pulp-platform/fpga-support/rtl/SyncSpRam.sv")])
        + list([Path(SCRIPT_DIR / "../../cva6-softcore-contest/vendor/pulp-platform/fpga-support/rtl/SyncSpRamBeNx64.sv")])
        + list([Path(SCRIPT_DIR / "../../cva6-softcore-contest/vendor/pulp-platform/fpga-support/rtl/AsyncDpRam.sv")])
        + list([Path(SCRIPT_DIR / "../../cva6-softcore-contest/vendor/pulp-platform/fpga-support/rtl/SyncDpRam.sv")])
        + list([Path(SCRIPT_DIR / "../../cva6-softcore-contest/vendor/pulp-platform/fpga-support/rtl/AsyncThreePortRam.sv")])
        + list(pkg_sv_paths)
        + list(other_paths)
    )

    include_dirs = [
        header.parent
        for header in list(verilog_headers)
        + list(system_verilog_headers)
        + list(submodule_verilog_headers)
        + list(submodule_system_verilog_headers)

        + list([Path(SCRIPT_DIR / "../../cva6-softcore-contest/corev_apu/tb")])
    ]
    # + list(pre_pkg_sv_paths)

    # subdirectories = [x[0] for x in os.walk(hdl_dir)]
    # include_dirs.extend(subdirectories)

    for submodule_dir in submodule_dirs:
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
