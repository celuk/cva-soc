from pathlib import Path
import os

SCRIPT_DIR = Path(os.path.realpath(__file__)).parent.absolute()

coremark = {
    "coremark": {
        "TEST_FILE": f"{SCRIPT_DIR}/../../tests/coremark/coremark_baremetal.hex",
        "fail_adr": 0x40F00060,
        "pass_adr": 0x40F00078,
        "instructions": [],
    }
}
