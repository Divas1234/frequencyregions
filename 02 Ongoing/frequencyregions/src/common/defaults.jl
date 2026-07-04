function default_controller_config()
    controller_config = converter_forming_configurations()
    return ControllerConfig(
        controller_config["VSM"]["control_parameters"],
        controller_config["Droop"]["control_parameters"],
    )
end
