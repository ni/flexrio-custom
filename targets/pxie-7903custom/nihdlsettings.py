"""nihdlsettings.py - Target settings for pxie-7903custom."""


def pre_all(context):
    """Configure all settings for pxie-7903custom."""
    config = context.config

    # --- Settings Variables ---
    base_deps = "../../deps/flexrio/targets/pxie-7903"
    plugin_name = "PXIe-7903Custom"

    # --- Tools ---
    config.set_vivado_tools_folder("C:/NIFPGA/programs/Vivado2021_1")
    config.set_vivado_tcl_scripts_folder("../common/TCL")
    config.set_modelsim_tools_folder("C:/modeltech_pe_2020.4")
    config.set_xilinx_sim_lib_folder("C:/dev/libraries/vivado/2021.1/modelsim_PE_2020")

    # --- General Settings ---
    config.set_target_family("FlexRIO")
    config.set_base_target("PXIe-7903")

    # --- Dependencies ---
    config.set_dependencies("../../dependencies.toml")

    # --- HDL Source Code ---
    config.add_hdl_file_list(f"{base_deps}/vivadoprojectdeps.txt")
    config.add_hdl_file_list("vivadoprojectsources.txt")
    config.add_hdl_file_list("../../deps/flexrio-deps/hdl_shared_deps_list/hdlsharedvivadoprojectdeps.txt")

    # Exclude the US PkgNiDmaConfig.vhd from the shared deps list; this USP target
    # supplies the correct USP copy via its own vivadoprojectdeps.txt.
    config.add_exclude_hdl_file_list("vivadoprojectexclude.txt")

    # --- LabVIEW Window Netlist for Synthesis ---
    # This example contains a netlist that was generated using the LabVIEW project in the docs folder.
    # When you generate your own netlist from a LabVIEW FPGA VI, change this path to point to the folder
    # containing the generated netlist (e.g., "objects/TheLvWindowNetlist").
    # This example contains a pre-generated netlist using the LabVIEW project in the docs folder.  
    # When you generate your own netlist, change this path to point to the folder containing the 
    # generated netlist (e.g., "objects/TheLvWindowNetlist").
    config.set_lv_window_netlist_folder("blankLvWindowNetlist")
 
    # --- Vivado Project Settings ---
    config.set_vivado_top_entity("SasquatchTopTemplate")
    config.set_fpga_part("xcvu11p-flgb2104-2-e")
    config.set_vivado_project_folder("VivadoProject")

    # --- Vivado Constraints ---
    config.add_constraints_template(f"{base_deps}/xdc/constraints.xdc_template")
    config.set_custom_constraints("xdc/custom_constraints.xdc")
    config.add_vivado_project_constraints(f"{base_deps}/xdc/constraints_place.xdc")
    config.add_vivado_project_constraints("objects/xdc/constraints.xdc")

    # --- LabVIEW FPGA Target Settings ---
    config.set_lv_target_name("PXIe-7903Custom")
    config.set_lv_target_guid("4ad9cfc3-df38-4086-9d0b-02bca6b24719")
    config.set_lv_target_install_folder("C:/Program Files/NI/LVAddons/flexrioii/1/Targets/NI/FPGA/RIO/79XXR")
    config.set_lv_target_menus_folder("../../deps/flexrio/targets/common/lvFpgaTarget/targetpluginmenus")
    config.set_lv_target_info_ini(f"{base_deps}/lvFpgaTarget/TargetInfo.ini")
    config.add_lv_target_exclude_files(f"{base_deps}/lvtargetexcludefiles.txt")
    config.add_lv_target_exclude_files("../../deps/flexrio-deps/hdl_shared_deps_list/hdlsharedlvtargetexcludefiles.txt")
    config.set_lv_target_plugin_output_folder(f"objects/LVTargetPlugin/{plugin_name}")

    # --- LabVIEW FPGA Target Constraints ---
    config.add_lv_target_constraints(f"{base_deps}/xdc/constraints.xdc_template")
    config.add_lv_target_constraints(f"{base_deps}/xdc/constraints_place.xdc")

    # --- LabVIEW FPGA Target IO ---
    config.set_custom_io_csv("lvFpgaTarget/LVTargetBoardIO.csv")
    config.set_include_board_io_on_lv_window(False)
    config.set_include_custom_io_on_lv_window(False)

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
    config.set_max_hdl_reg_offset(1024)  # Pick a large number to give us plenty of headroom

    # --- CLIP Migration Settings ---
    config.set_clip_input_xml("")
    config.set_clip_top_hdl("")
    config.add_clip_constraints("")
    config.set_clip_entity_path("")
    config.set_clip_output_csv("lvFpgaTarget/LVTargetBoardIO.csv")
    config.set_clip_inst_example("objects/CLIPMigration/CLIPInstantiationExample.vhd")
    config.set_clip_to_window_signal_definitions("objects/CLIPMigration/CLIPtoWindowSignalDefinitions.vhd")
    config.set_clip_output_xdc_folder("objects/CLIPMigration/xdc")

    # --- Generate LV Window Netlist Settings ---
    config.set_lv_window_vivado_project_export_xpr(r"C:\temp\MyProjectVPE\MyProject.xpr")
    config.set_lv_window_netlist_output_folder("objects/TheLvWindowNetlist")

    # --- Window Hierarchy Settings ---
    config.set_entity_path_to_window("TheLvWindowWrapper/TheLvWindow")
    config.set_entity_path_to_window_wrapper("TheLvWindowWrapper")

    # --- ModelSim Project Settings ---
    config.set_modelsim_project_folder("ModelSimProject")
    config.set_modelsim_top_entity("tb_UserHdl")
    config.add_modelsim_file_list("modelsimprojectsources.txt")
    config.add_modelsim_file_list("../../deps/flexrio-deps/hdl_shared_deps_list/hdlsharedvivadoprojectdeps.txt")


def post_all(context):
    """Called after every command completes."""
    pass
