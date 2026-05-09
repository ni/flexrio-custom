"""nihdlsettings.py for the target-smoke-tests pipeline.

Loads each target's own nihdlsettings.py from the invocation directory,
then applies pipeline-specific overrides (skip Vivado/ModelSim so
gen-vivado validates settings without requiring tool installations).
"""

import os

from labview_fpga_hdl_tools.command_hooks import load_settings


def pre_all(context):
    """Load the target's settings, then apply smoke-test overrides."""
    target_settings = os.path.join(context.invocation_dir, "nihdlsettings.py")
    load_settings(target_settings, context)

    # Smoke tests run without Vivado/ModelSim installed
    context.config.set_skip_vivado(True)
    context.config.set_skip_modelsim(True)
