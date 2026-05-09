"""nihdlsettings.py - Target settings for pxie-7903aurora."""


def pre_all(context):
    """Configure all settings for pxie-7903aurora."""
    config = context.config

    # --- Settings Variables ---
    base_deps = "../../deps/flexrio/targets/pxie-7903"
    plugin_name = "PXIe-7903Aurora"
    clip_deps = "../../dependencies/githubdeps/ni.hw-flexrio.sasquatch_aurora64b66b_clip.25.5.0.11-ci-passed-main-f/aurora64b66b_framing_crcx4_28p0GHz/CLIP/aurora64b66b_framing_crcx4_28p0GHz/Source"

    # --- Tools ---
    config.set_vivado_tools_folder("C:/NIFPGA/programs/Vivado2021_1")
    config.set_vivado_tcl_scripts_folder("../common/TCL")
    config.set_modelsim_tools_folder("")
    config.set_xilinx_sim_lib_folder("")

    # --- General Settings ---
    config.set_target_family("FlexRIO")
    config.set_base_target("PXIe-7903")

     # --- Dependencies ---   
    config.set_dependencies("../../dependencies.toml")

    # --- HDL Source Code ---
    config.add_hdl_file_list(f"{base_deps}/vivadoprojectdeps.txt")
    config.add_hdl_file_list("vivadoprojectsources.txt")
    config.add_hdl_file_list("vivadoprojectclipsources.txt")

    # --- LabVIEW Window Netlist for Synthesis ---
    config.set_lv_window_netlist_folder("objects/TheWindow")

    # --- Vivado Project Settings ---
    config.set_top_level_entity("SasquatchTopTemplate")
    config.set_fpga_part("xcvu11p-flgb2104-2-e")
    config.set_vivado_project_folder("VivadoProject")

    # --- Vivado Constraints ---
    config.add_constraints_template(f"{base_deps}/xdc/constraints.xdc_template")
    config.set_custom_constraints("xdc/custom_constraints.xdc")
    config.add_vivado_project_constraints(f"{base_deps}/xdc/constraints_place.xdc")
    config.add_vivado_project_constraints("objects/xdc/constraints.xdc")

    # --- LabVIEW FPGA Target Settings ---
    config.set_lv_target_name("PXIe-7903Aurora")
    config.set_lv_target_guid("8943868e-fc0c-4e48-a2e9-1ebce7779d5c")
    config.set_lv_target_install_folder("C:/Program Files/NI/LVAddons/flexrioii/1/Targets/NI/FPGA/RIO/79XXR")
    config.set_lv_target_menus_folder("../../deps/flexrio/targets/common/lvFpgaTarget/targetpluginmenus")
    config.set_lv_target_info_ini(f"{base_deps}/lvFpgaTarget/TargetInfo.ini")
    config.set_lv_target_exclude_files(f"{base_deps}/lvtargetexcludefiles.txt")
    config.set_lv_target_plugin_output_folder(f"objects/LVTargetPlugin/{plugin_name}")

    # --- LabVIEW FPGA Target Constraints ---
    config.add_lv_target_constraints(f"{base_deps}/xdc/constraints.xdc_template")
    config.add_lv_target_constraints(f"{base_deps}/xdc/constraints_place.xdc")

    # --- LabVIEW FPGA Target IO ---
    config.set_custom_io_csv("lvFpgaTarget/LVTargetBoardIO.csv")
    config.set_include_board_io_on_lv_window(False)
    config.set_include_custom_io_on_lv_window(True)

    # --- LabVIEW FPGA Target Generated VHDL ---
    config.add_window_vhdl_template(f"{base_deps}/rtl-lvfpga/lvgen/TheWindow.vhd.mako")
    config.add_window_vhdl_template("rtl-lvfpga/TheLvWindowFlatWrapper.vhd.mako")
    config.add_window_vhdl_template("rtl-lvfpga/PkgTheLvWindowFlatWrapper.vhd.mako")
    config.set_window_vhdl_output_folder("objects/GeneratedHDL")

    # --- LabVIEW FPGA Target Generated Resource XML ---
    config.add_lv_target_xml_template(f"{base_deps}/lvFpgaTarget/Resource.xml.mako")
    config.add_lv_target_xml_template(f"{base_deps}/lvFpgaTarget/Sasquatch7903.xml.mako")
    config.set_boardio_output(f"objects/LVTargetPlugin/{plugin_name}/boardio.xml")
    config.set_clock_output(f"objects/LVTargetPlugin/{plugin_name}/CustomClocks.xml")

    # --- HDL-to-Host Interfaces ---
    config.set_max_hdl_reg_offset(0)

    # --- CLIP Migration Settings ---
    config.set_clip_input_xml(f"{clip_deps}/xml/PXIe7903_Aurora64b66b_Framing_Crcx4_28p0GHz.xml")
    config.set_clip_top_hdl(f"{clip_deps}/vhdl/UserRTL_PXIe7903_Aurora64b66b_Framing_Crcx4_28p0GHz.vhd")
    config.add_clip_constraints(f"{clip_deps}/xdc/PXIe7903_Aurora64b66b_Framing_Crcx4_28p0GHz.xdc")
    config.add_clip_constraints(f"{clip_deps}/xdc/PXIe7903_microblaze_debug_place.xdc")
    config.set_clip_entity_path("UserRTL_PXIe7903_Aurora64b66b_Framing_Crcx4_28p0GHz_inst")
    config.set_clip_output_csv("lvFpgaTarget/LVTargetBoardIO.csv")
    config.set_clip_inst_example("objects/CLIPMigration/CLIPInstantiationExample.vhd")
    config.set_clip_to_window_signal_definitions("objects/CLIPMigration/CLIPtoWindowSignalDefinitions.vhd")
    config.set_clip_output_xdc_folder("objects/CLIPMigration/xdc")

    # --- Generate LV Window Netlist Settings ---
    config.set_lv_window_vivado_project_export_xpr("C:/temp/GH9_AC_VPE_A/VivadoProject/Top_FPGA_dash_2_dash_port.xpr")
    config.set_lv_window_netlist_output_folder("objects/TheWindow")

    # --- Window Hierarchy Settings ---
    config.set_entity_path_to_window("TheLvWindowWrapper/TheLvWindow")
    config.set_entity_path_to_window_wrapper("TheLvWindowWrapper")

    # --- ModelSim Project Settings ---
    config.set_modelsim_project_folder("ModelSimProject")


def post_all(context):
    """Called after every command completes."""
    pass
