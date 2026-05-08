"""nihdlsettings.py - Target settings for pxie-7985custom."""


def pre_all(context):
    """Configure all settings for pxie-7985custom."""
    config = context.config

    # --- Tools ---
    config.set_vivado_tools_path("C:/NIFPGA/programs/Vivado2021_1")
    config.set_vivado_tcl_scripts_folder("../common/TCL")
    # config.set_modelsim_tools_path("")
    # config.set_xilinx_sim_lib_path("")

    # --- General Settings ---
    config.set_target_family("FlexRIO")
    config.set_base_target("PXIe-7985")
    config.set_dependencies("../../dependencies.toml")

    # --- Vivado Project Settings ---
    config.set_top_level_entity("MacallanTop")
    config.set_fpga_part("xcku060-ffva1156-2-e")
    config.set_vivado_project_path("VivadoProject/My7985Proj.xpr")

    config.add_hdl_file_list("../../deps/flexrio/targets/pxie-7985/vivadoprojectdeps.txt")
    config.add_hdl_file_list("vivadoprojectsources.txt")

    config.add_constraints_template("../../deps/flexrio/targets/pxie-7985/xdc/constraints.xdc")
    config.set_custom_constraints_file("xdc/custom_constraints.xdc")
    config.add_vivado_project_constraints_file(
        "../../deps/flexrio/targets/pxie-7985/xdc/constraints_place.xdc"
    )
    config.add_vivado_project_constraints_file("objects/xdc/constraints.xdc")

    config.set_use_gen_lv_window_files(True)
    config.set_the_window_folder_input("lvWindowNetlist")
    config.set_code_generation_results_stub(
        "../../deps/flexrio/targets/pxie-7985/lvFpgaTarget/CodeGenerationResultsStub.lvtxt"
    )

    # --- LVFPGA Target Settings ---
    config.set_custom_signals_csv("lvFpgaTarget/LVTargetBoardIO.csv")
    config.set_include_target_io_ports(False)
    config.set_include_custom_io(False)
    config.set_lv_target_name("PXIe-7985Custom")
    config.set_lv_target_guid("492545ca-a6f5-4abf-b85b-15c020eeb445")
    config.set_lv_target_install_folder(
        "C:/Program Files/NI/LVAddons/flexrioii/1/Targets/NI/FPGA/RIO/79XXR"
    )

    config.add_lv_target_constraints_file(
        "../../deps/flexrio/targets/pxie-7985/xdc/constraints.xdc"
    )
    config.add_lv_target_constraints_file(
        "../../deps/flexrio/targets/pxie-7985/xdc/constraints_place.xdc"
    )
    config.set_lv_target_menus_folder(
        "../../deps/flexrio/targets/common/lvFpgaTarget/targetpluginmenus"
    )
    config.set_lv_target_info_ini(
        "../../deps/flexrio/targets/pxie-7985/lvFpgaTarget/TargetInfo.ini"
    )
    config.set_lv_target_exclude_files(
        "../../deps/flexrio/targets/pxie-7985/lvtargetexcludefiles.txt"
    )
    config.set_max_hdl_reg_offset(16)

    # Templates
    config.add_window_vhdl_template(
        "../../deps/flexrio/targets/pxie-7985/rtl-lvfpga/lvgen/TheWindow.vhd.mako"
    )
    config.add_window_vhdl_template("rtl-lvfpga/TheLvWindowFlatWrapper.vhd.mako")
    config.add_window_vhdl_template("rtl-lvfpga/PkgTheLvWindowFlatWrapper.vhd.mako")
    config.add_target_xml_template(
        "../../deps/flexrio/targets/pxie-7985/lvFpgaTarget/Resource.xml.mako"
    )
    config.add_target_xml_template(
        "../../deps/flexrio/targets/pxie-7985/lvFpgaTarget/Macallan7985.xml.mako"
    )

    # Outputs
    config.set_window_vhdl_output_folder("objects/GeneratedHDL")
    config.set_board_io_signal_assignments_example(
        "objects/GeneratedHDL/BoardIOSignalAssignmentsExample.vhd"
    )
    config.set_lv_target_plugin_folder("objects/LVTargetPlugin/PXIe-7985Custom")
    config.set_boardio_output("objects/LVTargetPlugin/PXIe-7985Custom/boardio.xml")
    config.set_clock_output("objects/LVTargetPlugin/PXIe-7985Custom/CustomClocks.xml")

    # --- CLIP Migration Settings ---
    # config.set_input_xml_path("")
    # config.set_clip_hdl_path("")
    # config.add_clip_xdc_path("")
    # config.set_clip_instance_path("")

    config.set_output_csv_path("lvFpgaTarget/LVTargetBoardIO.csv")
    config.set_clip_inst_example_path("objects/CLIPMigration/CLIPInstantiationExample.vhd")
    config.set_clip_to_window_signal_definitions(
        "objects/CLIPMigration/CLIPtoWindowSignalDefinitions.vhd"
    )
    config.set_updated_xdc_folder("objects/CLIPMigration/xdc")

    # --- LV Window Netlist Settings ---
    config.set_vivado_project_export_xpr("C:/temp/customwindow/7985_VPE/VivadoProject/Running8.xpr")
    config.set_the_window_folder_output("objects/TheWindow")

    # --- Window Hierarchy Settings ---
    config.set_entity_path_to_window("TheLvWindowWrapper/TheLvWindow")
    config.set_entity_path_to_window_wrapper("TheLvWindowWrapper")

    # --- ModelSim Settings ---
    config.set_modelsim_project_path("ModelSimProject/My7985Proj.mpf")


def post_all(context):
    """Called after every command completes."""
    pass
