"""nihdlsettings.py - Target settings for pxie-7994custom."""


def pre_all(context):
    """Configure all settings for pxie-7994custom."""
    config = context.config

    # --- Tools ---
    config.set_vivado_tools_folder("C:/NIFPGA/programs/Vivado2021_1")
    config.set_vivado_tcl_scripts_folder("../common/TCL")
    # config.set_modelsim_tools_folder("")
    # config.set_xilinx_sim_lib_folder("")

    # --- General Settings ---
    config.set_target_family("FlexRIO")
    config.set_base_target("PXIe-7994")
    config.set_dependencies("../../dependencies.toml")

    # --- Vivado Project Settings ---
    config.set_top_level_entity("BTracePlusTopTemplate")
    config.set_fpga_part("xcku060-ffva1156-2-e")
    config.set_vivado_project_folder("VivadoProject/My7994Proj.xpr")

    config.add_hdl_file_list("../../deps/flexrio/targets/pxie-7994/vivadoprojectdeps.txt")
    config.add_hdl_file_list("vivadoprojectsources.txt")

    config.add_constraints_template("../../deps/flexrio/targets/pxie-7994/xdc/constraints.xdc")
    config.set_custom_constraints("xdc/custom_constraints.xdc")
    config.add_vivado_project_constraints(
        "../../deps/flexrio/targets/pxie-7994/xdc/constraints_place.xdc"
    )
    config.add_vivado_project_constraints("objects/xdc/constraints.xdc")

    config.set_lv_window_netlist_folder("lvWindowNetlist")

    # --- LVFPGA Target Settings ---
    config.set_custom_io_csv("lvFpgaTarget/LVTargetBoardIO.csv")
    config.set_include_board_io_on_lv_window(False)
    config.set_include_custom_io_on_lv_window(False)
    config.set_lv_target_name("PXIe-7994Custom")
    config.set_lv_target_guid("bde9fc6e-df2b-4d42-a5e3-51f2f16f5f31")
    config.set_lv_target_install_folder(
        "C:/Program Files/NI/LVAddons/flexrioii/1/Targets/NI/FPGA/RIO/79XXR"
    )

    config.add_lv_target_constraints(
        "../../deps/flexrio/targets/pxie-7994/xdc/constraints.xdc"
    )
    config.add_lv_target_constraints(
        "../../deps/flexrio/targets/pxie-7994/xdc/constraints_place.xdc"
    )
    config.set_lv_target_menus_folder(
        "../../deps/flexrio/targets/common/lvFpgaTarget/targetpluginmenus"
    )
    config.set_lv_target_info_ini(
        "../../deps/flexrio/targets/pxie-7994/lvFpgaTarget/TargetInfo.ini"
    )
    config.set_lv_target_exclude_files(
        "../../deps/flexrio/targets/pxie-7994/lvtargetexcludefiles.txt"
    )
    config.set_max_hdl_reg_offset(16)

    # Templates
    config.add_window_vhdl_template(
        "../../deps/flexrio/targets/pxie-7994/rtl-lvfpga/lvgen/TheWindow.vhd.mako"
    )
    config.add_window_vhdl_template("rtl-lvfpga/TheLvWindowFlatWrapper.vhd.mako")
    config.add_window_vhdl_template("rtl-lvfpga/PkgTheLvWindowFlatWrapper.vhd.mako")
    config.add_lv_target_xml_template(
        "../../deps/flexrio/targets/pxie-7994/lvFpgaTarget/Resource.xml.mako"
    )
    config.add_lv_target_xml_template(
        "../../deps/flexrio/targets/pxie-7994/lvFpgaTarget/BTracePlus7994.xml.mako"
    )

    # Outputs
    config.set_window_vhdl_output_folder("objects/GeneratedHDL")
    config.set_lv_target_plugin_output_folder("objects/LVTargetPlugin/PXIe-7994Custom")
    config.set_boardio_output("objects/LVTargetPlugin/PXIe-7994Custom/boardio.xml")
    config.set_clock_output("objects/LVTargetPlugin/PXIe-7994Custom/CustomClocks.xml")

    # --- CLIP Migration Settings ---
    # config.set_input_xml_path("")
    # config.set_clip_top_hdl("")
    # config.add_clip_constraints("")
    # config.set_clip_entity_path("")

    config.set_clip_output_csv("lvFpgaTarget/LVTargetBoardIO.csv")
    config.set_clip_inst_example("objects/CLIPMigration/CLIPInstantiationExample.vhd")
    config.set_clip_to_window_signal_definitions(
        "objects/CLIPMigration/CLIPtoWindowSignalDefinitions.vhd"
    )
    config.set_clip_output_xdc_folder("objects/CLIPMigration/xdc")

    # --- LV Window Netlist Settings ---
    config.set_lv_window_vivado_project_export_xpr(
        "C:/temp/customwindow/7994_VPE/VivadoProject/Running10.xpr"
    )
    config.set_lv_window_netlist_output_folder("objects/TheWindow")

    # --- Window Hierarchy Settings ---
    config.set_entity_path_to_window("TheLvWindowWrapper/TheLvWindow")
    config.set_entity_path_to_window_wrapper("TheLvWindowWrapper")

    # --- ModelSim Settings ---
    config.set_modelsim_project_folder("ModelSimProject/My7994Proj.mpf")


def post_all(context):
    """Called after every command completes."""
    pass
