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
    # This example contains a netlist that was generated using the LabVIEW project in the docs folder.
    # When you generate your own netlist from a LabVIEW FPGA VI, change this path to point to the folder
    # containing the generated netlist (e.g., "objects/TheLvWindowNetlist").
    #
    # This example ships with the blank LabVIEW window netlist that does not contain the code necessary to 
    # run the Aurora IP.  We use the blank netlist so tha the design will compile.  The Aurora example's 
    # netlist is too large to put on GitHub so you will need to generate a Vivado Project Export from the 
    # Aurora example and generate the netlist from that.
    config.set_lv_window_netlist_folder("blankLvWindowNetlist")

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
    config.set_max_hdl_reg_offset(0)  # This example does not use any HDL registers

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
    config.set_lv_window_vivado_project_export_xpr(r"C:\Temp\testVPE\PXIe-7903Aurora_VPE\VivadoProject\BlankRunningVI.xpr")
    config.set_lv_window_netlist_output_folder("objects/TheLvWindowNetlist")

    # --- Window Hierarchy Settings ---
    config.set_entity_path_to_window("TheLvWindowWrapper/TheLvWindow")
    config.set_entity_path_to_window_wrapper("TheLvWindowWrapper")

    # --- ModelSim Project Settings ---
    config.set_modelsim_project_folder("ModelSimProject")


def post_all(context):
    """Called after every command completes."""
    pass
