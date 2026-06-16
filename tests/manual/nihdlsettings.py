"""Shared wrapper nihdlsettings.py for the target tests.

This wrapper is passed to nihdl via ``--config=<this file>`` by the test
shell ``run_tests.py``. It loads each target's own nihdlsettings.py from the
invocation directory, then applies test overrides so the tests use
known-good, machine-independent paths instead of the per-developer paths in
the target settings:

  * ``set_lv_window_netlist_output_folder`` (the gen-window *output* folder)
    defaults to the scratch ``objects/testLvWindowNetlist`` folder (not checked
    in). Passing ``--set lv_window_output=shipping`` on the nihdl command line
    instead sends it to the checked-in ("shipping") netlist folder at the target
    root (``blankLvWindowNetlist`` for most targets, ``fifoTestLvWindowNetlist``
    for PXIe-7912fifotest).
  * ``set_lv_window_vivado_project_export_xpr`` is ALWAYS overridden to
    ``c:\temp\testVPE\<targetname>_VPE\VivadoProject\<xpr>``, where
    ``<targetname>`` is the target's LabVIEW target name (e.g.
    ``PXIe-7903Custom``) and ``<xpr>`` is the per-target VPE project file
    (``BlankRunningVI.xpr`` for most targets, ``Aurora2port.xpr`` for
    PXIe-7903Aurora, ``FifoTestFPGA.xpr`` for PXIe-7912fifotest).
  * ``set_lv_window_netlist_folder`` (the *input* netlist folder) is left as the
    target's own value by default. Passing ``--set lv_window_input=objects`` on
    the nihdl command line instead points it at the generated netlist under the
    target's ``objects`` folder.

The behavior is driven entirely by generic ``--set KEY=VALUE`` overrides that
nihdl exposes to hooks as ``context.settings`` -- no per-variant wrapper files
and no environment variables. The shared override logic lives in
``apply_test_overrides``; the ``pre_all`` hook reads the recognized ``--set``
keys and applies it.
"""

import os

from labview_fpga_hdl_tools.command_hooks import load_settings

# Checked-in ("shipping") LV window netlist folder at each target's root. This is
# the netlist committed to GitHub; gen-window writes here only when asked to
# regenerate the shipping netlist (--set lv_window_output=shipping). Almost all
# targets use blankLvWindowNetlist; a few use a different name. Keyed by target
# name.
DEFAULT_SHIPPING_LV_WINDOW_SUBFOLDER_NAME = "blankLvWindowNetlist"
SHIPPING_LV_WINDOW_SUBFOLDER_NAME_BY_TARGET = {
    "PXIe-7912fifotest": "fifoTestLvWindowNetlist",
}

# Scratch LV window netlist folder under each target's objects/ folder. This is
# the default gen-window output location (not checked in) and the netlist that
# gen-vivado reads when run with --set lv_window_input=objects.
OBJECTS_LV_WINDOW_SUBFOLDER_NAME = "testLvWindowNetlist"

# The exported VPE .xpr file name to use per target. Almost all targets use
# BlankRunningVI.xpr; a few use a different VI. Keyed by LabVIEW target name.
DEFAULT_VPE_XPR_NAME = "BlankRunningVI.xpr"
VPE_XPR_NAME_BY_TARGET = {
    "PXIe-7912fifotest": "FifoTestLvFPGA.xpr",
}


def apply_test_overrides(
    context, use_objects_lv_window=False, write_shipping_netlist=False
):
    """Load the target's settings, then override the window netlist folders.

    Args:
        context: The nihdl CommandContext.
        use_objects_lv_window: When True, point the *input* window netlist
            folder (``set_lv_window_netlist_folder``, read by gen-vivado) at the
            generated netlist under the target's ``objects`` folder. When False
            (the default), keep the lvWindowNetlist folder from the target's own
            nihdlsettings.py.
        write_shipping_netlist: When True, send the gen-window *output*
            (``set_lv_window_netlist_output_folder``) to the checked-in
            ("shipping") netlist folder at the target root. When False (the
            default), send it to the scratch ``objects`` folder.
    """
    target_settings = os.path.join(context.invocation_dir, "nihdlsettings.py")
    load_settings(target_settings, context)

    target_name = context.config.lv_target_name

    # Build absolute paths under the target directory. The setters resolve
    # relative paths against the current working directory, which during this
    # hook is this wrapper's directory -- not the target -- so we must anchor
    # the paths to the invocation (target) directory explicitly.

    # Checked-in ("shipping") netlist folder at the target root (per-target name).
    shipping_subfolder_name = SHIPPING_LV_WINDOW_SUBFOLDER_NAME_BY_TARGET.get(
        target_name, DEFAULT_SHIPPING_LV_WINDOW_SUBFOLDER_NAME
    )
    shipping_window_folder = os.path.join(
        context.invocation_dir, shipping_subfolder_name
    )

    # Scratch netlist folder under objects/ (not checked in).
    objects_window_folder = os.path.join(
        context.invocation_dir, "objects", OBJECTS_LV_WINDOW_SUBFOLDER_NAME
    )

    # gen-window output: the checked-in shipping folder when regenerating the
    # shipping netlist, otherwise the scratch objects/ folder (the default).
    output_folder = (
        shipping_window_folder if write_shipping_netlist else objects_window_folder
    )
    context.config.set_lv_window_netlist_output_folder(output_folder)

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

    # gen-vivado input: read the generated objects/ netlist when requested;
    # otherwise keep the target-specific folder loaded above.
    if use_objects_lv_window:
        context.config.set_lv_window_netlist_folder(objects_window_folder)


def pre_all(context):
    """Wrapper hook: apply test overrides, honoring generic --set CLI overrides.

    Recognized ``--set`` keys (passed to nihdl on the command line):
      * ``lv_window_input=objects``    gen-vivado reads the generated objects/
        netlist (default: the target's own input folder).
      * ``lv_window_output=shipping``  gen-window writes the checked-in shipping
        netlist at the target root (default: the scratch objects/ folder).
    """
    apply_test_overrides(
        context,
        use_objects_lv_window=context.settings.get("lv_window_input") == "objects",
        write_shipping_netlist=context.settings.get("lv_window_output") == "shipping",
    )
