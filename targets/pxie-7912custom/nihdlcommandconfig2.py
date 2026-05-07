"""nihdlcommandconfig2.py - Standalone configuration without projectsettings.ini.

All settings are configured directly via setters in pre_all.
No projectsettings.ini file is required.

Hook execution order for each command:
    pre_all  →  pre_{command}  →  command  →  post_{command}  →  post_all
"""

import os


# Resolve paths relative to this file's directory (same as where INI would be)
_DIR = os.path.dirname(os.path.abspath(__file__))


def _resolve(relpath):
    """Resolve a relative path from this file's directory. Returns None if empty."""
    if not relpath:
        return None
    return os.path.normpath(os.path.join(_DIR, relpath))


# ---------------------------------------------------------------------------
# Global hooks – called for every command
# ---------------------------------------------------------------------------

def pre_all(context):
    """Called before every command. Configure all settings directly."""
    config = context.config

    # --- [Tools] ---
    config.set_lv_path(r"C:\Program Files\National Instruments\LabVIEW 2024")
    config.set_vivado_tools_path(r"C:\NIFPGA\programs\Vivado2021_1")
    config.set_vivado_tcl_scripts_folder(_resolve("../common/TCL"))
    # config.set_modelsim_tools_path("")
    # config.set_xilinx_sim_lib_path("")

    # --- [GeneralSettings] ---
    config.set_target_family("FlexRIO")
    config.set_base_target("PXIe-7912")
    config.set_dependencies(_resolve("../../dependencies.toml"))

    # --- [VivadoProjectSettings] ---
    config.set_top_level_entity("MacallanTop")
    config.set_fpga_part("xcku040-ffva1156-2-e")
    config.set_vivado_project_path("VivadoProject/My7912Proj.xpr")

    config.add_hdl_file_list(_resolve("../../deps/flexrio/targets/pxie-7912/vivadoprojectdeps.txt"))
    config.add_hdl_file_list(_resolve("vivadoprojectsources.txt"))
    config.add_hdl_file_list(_resolve("../../deps/flexrio-deps/hdl_shared_deps_list/hdlsharedvivadoprojectdeps.txt"))

    config.add_constraints_template(_resolve("../../deps/flexrio/targets/pxie-7912/xdc/constraints.xdc"))
    config.set_custom_constraints_file(_resolve("xdc/custom_constraints.xdc"))

    config.add_vivado_project_constraints_file(_resolve("../../deps/flexrio/targets/pxie-7912/xdc/constraints_place.xdc"))
    config.add_vivado_project_constraints_file(_resolve("objects/xdc/constraints.xdc"))

    config.set_use_gen_lv_window_files(True)
    config.set_the_window_folder_input(_resolve("lvWindowNetlist"))
    config.set_code_generation_results_stub(_resolve("../../deps/flexrio/targets/pxie-7912/lvFpgaTarget/CodeGenerationResultsStub.lvtxt"))

    # --- [LVFPGATargetSettings] ---
    config.set_custom_signals_csv(_resolve("lvFpgaTarget/LVTargetBoardIO.csv"))
    config.set_include_target_io_ports(False)
    config.set_include_custom_io(False)
    config.set_lv_target_name("PXIe-7912")
    config.set_lv_target_guid("64c7060e-22f3-4ad5-89f8-7ee4eeb3f5a3")
    config.set_lv_target_install_folder(r"C:\Program Files\NI\LVAddons\flexrioii\1\Targets\NI\FPGA\RIO\79XXR")

    config.add_lv_target_constraints_file(_resolve("../../deps/flexrio/targets/pxie-7912/xdc/constraints.xdc"))
    config.add_lv_target_constraints_file(_resolve("../../deps/flexrio/targets/pxie-7912/xdc/constraints_place.xdc"))

    config.set_lv_target_menus_folder(_resolve("../../deps/flexrio/targets/common/lvFpgaTarget/targetpluginmenus"))
    config.set_lv_target_info_ini(_resolve("../../deps/flexrio/targets/pxie-7912/lvFpgaTarget/TargetInfo.ini"))
    config.set_lv_target_exclude_files(_resolve("../../deps/flexrio/targets/pxie-7912/lvtargetexcludefiles.txt"))
    config.set_max_hdl_reg_offset(16)

    # Templates
    config.add_window_vhdl_template(_resolve("../../deps/flexrio/targets/pxie-7912/rtl-lvfpga/lvgen/TheWindow.vhd.mako"))
    config.add_window_vhdl_template(_resolve("rtl-lvfpga/TheLvWindowFlatWrapper.vhd.mako"))
    config.add_window_vhdl_template(_resolve("rtl-lvfpga/PkgTheLvWindowFlatWrapper.vhd.mako"))

    config.add_target_xml_template(_resolve("../../deps/flexrio/targets/pxie-7912/lvFpgaTarget/Resource.xml.mako"))
    config.add_target_xml_template(_resolve("../../deps/flexrio/targets/pxie-7912/lvFpgaTarget/Macallan7912.xml.mako"))

    # Outputs
    config.set_window_vhdl_output_folder(_resolve("objects/GeneratedHDL"))
    config.set_board_io_signal_assignments_example(_resolve("objects/GeneratedHDL/BoardIOSignalAssignmentsExample.vhd"))
    config.set_lv_target_plugin_folder(_resolve("objects/LVTargetPlugin/PXIe-7912Custom"))
    config.set_boardio_output(_resolve("objects/LVTargetPlugin/PXIe-7912Custom/boardio.xml"))
    config.set_clock_output(_resolve("objects/LVTargetPlugin/PXIe-7912Custom/CustomClocks.xml"))

    # --- [CLIPMigrationSettings] ---
    # CLIP inputs are empty for this target
    # config.set_input_xml_path(...)
    # config.set_clip_hdl_path(...)
    # config.set_clip_instance_path(...)

    # CLIP outputs
    config.set_output_csv_path(_resolve("lvFpgaTarget/LVTargetBoardIO.csv"))
    config.set_clip_inst_example_path(_resolve("objects/CLIPMigration/CLIPInstantiationExample.vhd"))
    config.set_clip_to_window_signal_definitions(_resolve("objects/CLIPMigration/CLIPtoWindowSignalDefinitions.vhd"))
    config.set_updated_xdc_folder(_resolve("objects/CLIPMigration/xdc"))

    # --- [LVWindowNetlistSettings] ---
    config.set_vivado_project_export_xpr(r"C:\temp\7912Cust_VPE_NoHdlFIFOs_3_Hack_2\VivadoProject\CustomBlankRunning.xpr")
    config.set_the_window_folder_output(_resolve("objects/TheWindowRunningFifos_NoHdlFIFOs_3_Hack_2"))

    # --- [ModelSimProjectSettings] ---
    # config.set_modelsim_project_path("")


def post_all(context):
    """Called after every command completes."""
    pass
