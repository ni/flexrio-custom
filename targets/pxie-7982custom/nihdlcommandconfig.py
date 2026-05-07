"""nihdlcommandconfig.py - Configuration and hooks for nihdl commands.

Hook execution order for each command:
    pre_all  →  pre_{command}  →  command  →  post_{command}  →  post_all

The context object passed to every hook has these attributes:
    context.config         - FileConfiguration (set it in pre_all)
    context.command_name   - e.g. "create_project"
    context.command_kwargs - dict of CLI arguments forwarded to the command
    context.result         - return value of the command (available in post hooks)
"""

import os

from labview_fpga_hdl_tools.common import load_config


# ---------------------------------------------------------------------------
# Global hooks – called for every command
# ---------------------------------------------------------------------------

def pre_all(context):
    """Called before every command. Load projectsettings.ini here."""
    ini_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "projectsettings.ini")
    load_config(ini_path=ini_path, config=context.config)


def post_all(context):
    """Called after every command completes."""
    pass


# ---------------------------------------------------------------------------
# Per-command hooks
# Uncomment and customize the hooks you need.
# ---------------------------------------------------------------------------

# def pre_create_project(context):
#     """Called before create-project."""
#     pass
#
# def post_create_project(context):
#     """Called after create-project."""
#     pass

# def pre_check_syntax(context):
#     """Called before check-syntax."""
#     pass
#
# def post_check_syntax(context):
#     """Called after check-syntax."""
#     pass

# def pre_compile_project(context):
#     """Called before compile-project."""
#     pass
#
# def post_compile_project(context):
#     """Called after compile-project."""
#     pass

# def pre_launch_vivado(context):
#     """Called before launch-vivado."""
#     pass
#
# def post_launch_vivado(context):
#     """Called after launch-vivado."""
#     pass

# def pre_get_window(context):
#     """Called before get-window."""
#     pass
#
# def post_get_window(context):
#     """Called after get-window."""
#     pass

# def pre_gen_target(context):
#     """Called before gen-target."""
#     pass
#
# def post_gen_target(context):
#     """Called after gen-target."""
#     pass

# def pre_gen_hdl(context):
#     """Called before gen-hdl."""
#     pass
#
# def post_gen_hdl(context):
#     """Called after gen-hdl."""
#     pass

# def pre_gen_xdc(context):
#     """Called before gen-xdc."""
#     pass
#
# def post_gen_xdc(context):
#     """Called after gen-xdc."""
#     pass

# def pre_gen_guid(context):
#     """Called before gen-guid."""
#     pass
#
# def post_gen_guid(context):
#     """Called after gen-guid."""
#     pass

# def pre_migrate_clip(context):
#     """Called before migrate-clip."""
#     pass
#
# def post_migrate_clip(context):
#     """Called after migrate-clip."""
#     pass

# def pre_install_target(context):
#     """Called before install-target."""
#     pass
#
# def post_install_target(context):
#     """Called after install-target."""
#     pass

# def pre_install_deps(context):
#     """Called before install-deps."""
#     pass
#
# def post_install_deps(context):
#     """Called after install-deps."""
#     pass

# def pre_create_modelsim(context):
#     """Called before create-modelsim."""
#     pass
#
# def post_create_modelsim(context):
#     """Called after create-modelsim."""
#     pass

# def pre_launch_modelsim(context):
#     """Called before launch-modelsim."""
#     pass
#
# def post_launch_modelsim(context):
#     """Called after launch-modelsim."""
#     pass

# def pre_sim_modelsim(context):
#     """Called before sim-modelsim."""
#     pass
#
# def post_sim_modelsim(context):
#     """Called after sim-modelsim."""
#     pass

# def pre_create_lvbitx(context):
#     """Called before create-lvbitx."""
#     pass
#
# def post_create_lvbitx(context):
#     """Called after create-lvbitx."""
#     pass
