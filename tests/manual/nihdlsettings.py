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
    ``c:\temp\testVPE\<vpe_folder>\VivadoProject\<xpr>``, where ``<xpr>`` is the
    VPE project file and ``<vpe_folder>`` is ``<targetname>_VPE`` for a
    single-VPE target (``BlankRunningVI.xpr`` for most targets, ``FifoTestLvFPGA.xpr``
    for PXIe-7912fifotest). Targets with several VPEs (LabVIEW examples) pick one
    per run via ``--set vpe=<key>``; each VPE names its own export folder via a
    suffix, so an empty suffix keeps the default ``<targetname>_VPE`` while a
    non-empty one gives ``<targetname>_<suffix>_VPE`` (e.g. PXIe-7903Aurora
    exports Blank Running VI to ``PXIe-7903Aurora_VPE`` and Aurora 2-port to
    ``PXIe-7903Aurora_2port_VPE``).
  * ``set_lv_window_netlist_folder`` (the *input* netlist folder) is left as the
    target's own value by default. Passing ``--set lv_window_input=objects`` on
    the nihdl command line instead points it at the generated netlist under the
    target's ``objects`` folder.
  * ``set_vivado_project_folder`` is overridden when ``--set vivado_project=<name>``
    is passed, so multi-VPE targets can build each VPE into its own Vivado
    project folder without the per-VPE builds clobbering each other.

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
# Targets with several VPEs (LabVIEW examples) are handled by
# VPE_VARIANTS_BY_TARGET instead and must NOT be listed here.
DEFAULT_VPE_XPR_NAME = "BlankRunningVI.xpr"
VPE_XPR_NAME_BY_TARGET = {
    "PXIe-7912fifotest": "FifoTestLvFPGA.xpr",
}

# Targets that build more than one VPE (LabVIEW example). The harness selects
# one per run via the generic ``--set vpe=<key>`` override, running such a
# target once per VPE it needs. Each variant maps its ``vpe`` key to a
# (xpr file name, VPE-folder suffix, netlist label) triple:
#   * xpr file name       -- the exported ``.xpr`` inside the VPE folder.
#   * VPE-folder suffix   -- picks the per-example VPE export folder
#     ``<TargetName>_<suffix>_VPE``; an empty suffix uses the plain default
#     ``<TargetName>_VPE`` (so a variant can share the single-VPE folder
#     convention).
#   * netlist label       -- suffixes the scratch objects netlist folder so two
#     VPEs built in the same run do not overwrite each other's generated
#     netlist.
# The ``vpe`` keys here must match the ones the harness sends (see
# MULTI_VPE_TARGETS in tests_common.py).
#
# PXIe-7903Aurora has an "Aurora 2-port" example and a plain "Blank Running VI"
# example. Only the Blank Running VI window netlist is committed to GitHub (the
# Aurora 2-port netlist is too large), so the harness builds BlankRunningVI in
# every mode and additionally builds Aurora2port only in the objects-window
# mode. The developer exports the Blank Running VI VPE to the default folder
# ``PXIe-7903Aurora_VPE`` (empty suffix) and the Aurora 2-port VPE to
# ``PXIe-7903Aurora_2port_VPE`` (suffix ``2port``). The Vivado project output
# folder is chosen by the harness and passed via ``--set vivado_project=<name>``
# so the per-VPE builds never collide.
VPE_VARIANTS_BY_TARGET = {
    "PXIe-7903Aurora": {
        "aurora2port": ("Aurora2port.xpr", "2port", "Aurora2port"),
        "blankrunningvi": ("BlankRunningVI.xpr", "", "BlankRunningVI"),
    },
}


def apply_test_overrides(
    context,
    use_objects_lv_window=False,
    write_shipping_netlist=False,
    vpe=None,
    vivado_project=None,
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
        vpe: For a multi-VPE target (see VPE_VARIANTS_BY_TARGET), the ``vpe``
            key selecting which VPE (LabVIEW example) to build. Chooses the
            .xpr file, the VPE export folder, and a per-VPE scratch netlist
            folder. Ignored for single-VPE targets and when None.
        vivado_project: When set, override the Vivado project output folder
            (``set_vivado_project_folder``) to this name under the target
            directory. Used so multi-VPE targets build each VPE into its own
            project folder without clobbering each other.
    """
    target_settings = os.path.join(context.invocation_dir, "nihdlsettings.py")
    load_settings(target_settings, context)

    target_name = context.config.lv_target_name

    # Resolve the VPE for this run. Targets with several VPEs (LabVIEW examples)
    # select one via the ``vpe`` key; the rest use their single per-target
    # default. ``vpe_folder_suffix`` picks the VPE export folder, and
    # ``vpe_label`` (when set) makes the scratch netlist folder variant-specific
    # so multiple VPEs of one target built in the same run stay separate.
    xpr_name = VPE_XPR_NAME_BY_TARGET.get(target_name, DEFAULT_VPE_XPR_NAME)
    vpe_folder_suffix = ""
    vpe_label = ""
    target_vpe_variants = VPE_VARIANTS_BY_TARGET.get(target_name)
    if target_vpe_variants and vpe:
        variant = target_vpe_variants.get(vpe)
        if variant:
            xpr_name, vpe_folder_suffix, vpe_label = variant

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

    # Scratch netlist folder under objects/ (not checked in). For a multi-VPE
    # target the folder is suffixed with the VPE label so each VPE's generated
    # netlist stays separate.
    objects_subfolder_name = OBJECTS_LV_WINDOW_SUBFOLDER_NAME
    if vpe_label:
        objects_subfolder_name += f"_{vpe_label}"
    objects_window_folder = os.path.join(
        context.invocation_dir, "objects", objects_subfolder_name
    )

    # gen-window output: the checked-in shipping folder when regenerating the
    # shipping netlist, otherwise the scratch objects/ folder (the default).
    output_folder = (
        shipping_window_folder if write_shipping_netlist else objects_window_folder
    )
    context.config.set_lv_window_netlist_output_folder(output_folder)

    # Always point the Vivado project export .xpr at a per-target test path. The
    # VPE export folder is ``<TargetName>_VPE`` when no suffix applies, or
    # ``<TargetName>_<suffix>_VPE`` when a VPE with a non-empty folder suffix was
    # selected (e.g. ``PXIe-7903Aurora_2port_VPE``).
    if target_name:
        vpe_folder = (
            f"{target_name}_{vpe_folder_suffix}_VPE"
            if vpe_folder_suffix
            else f"{target_name}_VPE"
        )
        xpr_path = os.path.join(
            r"c:\temp\testVPE",
            vpe_folder,
            "VivadoProject",
            xpr_name,
        )
        context.config.set_lv_window_vivado_project_export_xpr(xpr_path)

    # gen-vivado input: read the generated objects/ netlist when requested;
    # otherwise keep the target-specific folder loaded above.
    if use_objects_lv_window:
        context.config.set_lv_window_netlist_folder(objects_window_folder)

    # Multi-VPE targets build each VPE into its own Vivado project folder (chosen
    # by the harness) so the per-VPE builds do not collide. Anchor it to the
    # target directory, since relative paths set from this wrapper resolve
    # against the wrapper's own folder, not the target.
    if vivado_project:
        context.config.set_vivado_project_folder(
            os.path.join(context.invocation_dir, vivado_project)
        )


def pre_all(context):
    """Wrapper hook: apply test overrides, honoring generic --set CLI overrides.

    Recognized ``--set`` keys (passed to nihdl on the command line):
      * ``lv_window_input=objects``    gen-vivado reads the generated objects/
        netlist (default: the target's own input folder).
      * ``lv_window_output=shipping``  gen-window writes the checked-in shipping
        netlist at the target root (default: the scratch objects/ folder).
      * ``vpe=<key>``                  for a multi-VPE target, which VPE
        (LabVIEW example) to build; selects the .xpr, VPE export folder, and a
        per-VPE scratch netlist folder (see VPE_VARIANTS_BY_TARGET).
      * ``vivado_project=<name>``      override the Vivado project output folder
        so a multi-VPE target builds each VPE into its own folder.
      * ``use_xilinx_env=1``           override the Vivado tools folder from the
        XILINX environment variable (for CI/pipeline runs). No-op if XILINX is
        unset. Forwarded by run_tests.py's --xilinx-from-env flag.
      * ``use_modelsim_env=1``         override the ModelSim tools folder from
        the MODELSIM environment variable (for CI/pipeline runs). MODELSIM
        points at the modelsim.ini file, so its parent directory is used as the
        tools folder. No-op if MODELSIM is unset. Forwarded by run_tests.py's
        --modelsim-from-env flag.
    """
    apply_test_overrides(
        context,
        use_objects_lv_window=context.settings.get("lv_window_input") == "objects",
        write_shipping_netlist=context.settings.get("lv_window_output") == "shipping",
        vpe=context.settings.get("vpe"),
        vivado_project=context.settings.get("vivado_project"),
    )

    # CI/pipeline: select the Vivado install via the XILINX environment variable
    # when explicitly enabled. Applied after the target settings load so it
    # overrides any Vivado tools folder the target configured.
    if context.settings.get("use_xilinx_env"):
        xilinx_path = os.environ.get("XILINX")
        if xilinx_path:
            context.config.set_vivado_tools_folder(xilinx_path)

    # CI/pipeline: select the ModelSim install via the MODELSIM environment
    # variable when explicitly enabled. MODELSIM points at the modelsim.ini
    # file, so use its parent directory as the tools folder. Applied after the
    # target settings load so it overrides any ModelSim folder the target
    # configured.
    if context.settings.get("use_modelsim_env"):
        modelsim_ini = os.environ.get("MODELSIM")
        if modelsim_ini:
            context.config.set_modelsim_tools_folder(os.path.dirname(modelsim_ini))
