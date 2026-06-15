"""Shared wrapper nihdlsettings.py for the target tests.

This wrapper is passed to nihdl via ``--config=<this file>`` by the test
shell ``run_tests.py``. It loads each target's own nihdlsettings.py from the
invocation directory, then applies test overrides so the tests use
known-good, machine-independent paths instead of the per-developer paths in
the target settings:

  * ``set_lv_window_netlist_output_folder`` is ALWAYS overridden to a
    per-target subfolder under ``objects`` (``objects/blankLvWindowNetlist``
    for most targets, ``objects/auroraLvWindowNetlist`` for PXIe-7903Aurora,
    ``objects/fifoTestLvWindowNetlist`` for PXIe-7912fifotest).
  * ``set_lv_window_vivado_project_export_xpr`` is ALWAYS overridden to
    ``c:\temp\testVPE\<targetname>_VPE\VivadoProject\<xpr>``, where
    ``<targetname>`` is the target's LabVIEW target name (e.g.
    ``PXIe-7903Custom``) and ``<xpr>`` is the per-target VPE project file
    (``BlankRunningVI.xpr`` for most targets, ``Aurora2port.xpr`` for
    PXIe-7903Aurora, ``FifoTestFPGA.xpr`` for PXIe-7912fifotest).
  * ``set_lv_window_netlist_folder`` (the *input* netlist folder) is left as the
    target's own value by default, but is overridden to the same test folder
    when a test is run with ``--usetestlvwindow`` (signalled via the
    ``FLEXRIO_TEST_USE_TEST_LV_WINDOW`` environment variable set by the test
    script).
"""

import os

from labview_fpga_hdl_tools.command_hooks import load_settings

# Generated LV window netlist subfolder (under each target's objects/ folder).
# Almost all targets use blankLvWindowNetlist; a few use a different name.
# Keyed by LabVIEW target name.
DEFAULT_LV_WINDOW_SUBFOLDER_NAME = "blankLvWindowNetlist"
LV_WINDOW_SUBFOLDER_NAME_BY_TARGET = {
    "PXIe-7903Aurora": "auroraLvWindowNetlist",
    "PXIe-7912fifotest": "fifoTestLvWindowNetlist",
}

# Environment variable set by a test script when --usetestlvwindow is given.
USE_TEST_LV_WINDOW_ENV = "FLEXRIO_TEST_USE_TEST_LV_WINDOW"

# The exported VPE .xpr file name to use per target. Almost all targets use
# BlankRunningVI.xpr; a few use a different VI. Keyed by LabVIEW target name.
DEFAULT_VPE_XPR_NAME = "BlankRunningVI.xpr"
VPE_XPR_NAME_BY_TARGET = {
    "PXIe-7903Aurora": "Aurora2port.xpr",
    "PXIe-7912fifotest": "FifoTestLvFPGA.xpr",
}


def _use_test_lv_window():
    """Return True if the input netlist folder should also use the test folder."""
    return os.environ.get(USE_TEST_LV_WINDOW_ENV, "0").strip().lower() in (
        "1",
        "true",
        "yes",
    )


def pre_all(context):
    """Load the target's settings, then override the window netlist folders."""
    target_settings = os.path.join(context.invocation_dir, "nihdlsettings.py")
    load_settings(target_settings, context)

    target_name = context.config.lv_target_name

    # Build an absolute path under the target directory. The setters resolve
    # relative paths against the current working directory, which during this
    # hook is this wrapper's directory -- not the target -- so we must anchor
    # the path to the invocation (target) directory explicitly. The netlist
    # subfolder name is per-target (e.g. auroraLvWindowNetlist).
    subfolder_name = LV_WINDOW_SUBFOLDER_NAME_BY_TARGET.get(
        target_name, DEFAULT_LV_WINDOW_SUBFOLDER_NAME
    )
    test_window_folder = os.path.join(
        context.invocation_dir, "objects", subfolder_name
    )

    # Always send generated netlist output to the test folder.
    context.config.set_lv_window_netlist_output_folder(test_window_folder)

    # Always point the Vivado project export .xpr at a per-target test path,
    # using the target's LabVIEW target name (e.g. "PXIe-7903Custom").
    if target_name:
        xpr_name = VPE_XPR_NAME_BY_TARGET.get(target_name, DEFAULT_VPE_XPR_NAME)
        xpr_path = os.path.join(
            r"c:\temp\testVPE",
            f"{target_name}_VPE",
            "VivadoProject",
            xpr_name,
        )
        context.config.set_lv_window_vivado_project_export_xpr(xpr_path)

    # Only override the *input* netlist folder when explicitly requested;
    # otherwise keep the target-specific folder loaded above.
    if _use_test_lv_window():
        context.config.set_lv_window_netlist_folder(test_window_folder)
